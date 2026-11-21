# ============================================================
#  本地流水线（Local CI）
#  一条命令跑完全部阶段：  make ci
#  每个 make 目标对应未来 GitHub Actions 中的一个 job
#    check   -> 环境检查 / 语法编译
#    install -> 安装依赖（带缓存）
#    test    -> 跑测试，产出 JUnit 报告
#    build   -> 打包制品
#    docker  -> 构建镜像
# ============================================================

SHELL         := bash
.SHELLFLAGS   := -eu -o pipefail -c
.DEFAULT_GOAL := help

PYTHON  ?= python3
VENV    := .venv
BIN     := $(VENV)/bin
PIP     := $(BIN)/pip
PYTEST  := $(BIN)/pytest
SRC     := src
TESTS   := tests
REPORTS := reports
DIST    := dist
STAMP   := $(VENV)/.deps-stamp
IMAGE   ?= pipeline-demo
TAG     ?= local
VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo 0.0.0-dev)

.PHONY: help ci check install test build docker serve clean

help: ## 列出所有可用命令
	@echo "本地流水线命令："
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  make %-9s %s\n", $$1, $$2}'

ci: check install test build docker ## 跑完整条流水线
	@echo ""
	@echo "本地流水线全部通过 ✔   制品：$(DIST)/app-$(VERSION).tar.gz"

check: ## 阶段 1：检查 Python 版本并做语法编译
	@echo "── [1/5] 环境检查 ─────────────────────────────"
	@$(PYTHON) -c 'import sys; v = sys.version_info; sys.exit(0) if v >= (3, 10) else sys.exit("需要 Python >= 3.10，当前 %s" % sys.version.split()[0])'
	@$(PYTHON) -m compileall -q $(SRC) $(TESTS)
	@echo "   OK   $$($(PYTHON) --version 2>&1) / 语法检查通过"

install: ## 阶段 2：创建虚拟环境并安装依赖（requirements.txt 未变则跳过）
	@echo "── [2/5] 安装依赖 ─────────────────────────────"
	@test -d $(VENV) || $(PYTHON) -m venv $(VENV)
	@if [ -f $(STAMP) ] && [ $(STAMP) -nt requirements.txt ]; then \
		echo "   CACHED requirements.txt 未变化，跳过安装"; \
	else \
		$(PIP) install --quiet --upgrade pip && \
		$(PIP) install --quiet -r requirements.txt && \
		touch $(STAMP) && \
		echo "   OK   $$($(PYTEST) --version)"; \
	fi

test: install ## 阶段 3：运行测试并输出 JUnit 报告
	@echo "── [3/5] 运行测试 ─────────────────────────────"
	@mkdir -p $(REPORTS)
	@PYTHONPATH=$(SRC) $(PYTEST) -q --junitxml=$(REPORTS)/junit.xml
	@echo "   OK   报告已写入 $(REPORTS)/junit.xml"

build: test ## 阶段 4：打包可交付制品
	@echo "── [4/5] 构建制品 ─────────────────────────────"
	@mkdir -p $(DIST)
	@tar -czf $(DIST)/app-$(VERSION).tar.gz -C $(SRC) .
	@echo "   OK   $(DIST)/app-$(VERSION).tar.gz  $$(du -h $(DIST)/app-$(VERSION).tar.gz | cut -f1)"

docker: build ## 阶段 5：构建镜像（本机没有 docker 时自动跳过）
	@echo "── [5/5] 构建容器镜像 ────────────────────────"
	@if ! command -v docker >/dev/null 2>&1; then \
		echo "   SKIP 未检测到 docker，跳过该阶段"; \
	else \
		docker build -t $(IMAGE):$(TAG) . && echo "   OK   $(IMAGE):$(TAG)"; \
	fi

serve: install ## 本地启动服务，用于后续健康检查
	@PYTHONPATH=$(SRC) $(BIN)/python -m pipeline_demo.server

clean: ## 清理虚拟环境、报告与制品
	@rm -rf $(VENV) $(REPORTS) $(DIST) .pytest_cache
	@find . -name __pycache__ -type d -prune -exec rm -rf {} + 2>/dev/null || true
	@echo "已清理"
