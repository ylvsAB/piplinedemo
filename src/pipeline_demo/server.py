"""极简 HTTP 服务，便于后续做部署与健康检查。只用标准库。"""

import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs, urlparse

from .calculator import add


class Handler(BaseHTTPRequestHandler):
    def _send(self, code: int, payload: dict) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        parsed = urlparse(self.path)

        if parsed.path == "/health":
            return self._send(200, {"status": "ok"})

        if parsed.path == "/api/add":
            query = parse_qs(parsed.query)
            try:
                a = float(query["a"][0])
                b = float(query["b"][0])
            except (KeyError, ValueError):
                return self._send(400, {"error": "需要数字参数 a 和 b"})
            return self._send(200, {"result": add(a, b)})

        return self._send(404, {"error": "not found"})

    def log_message(self, fmt: str, *args) -> None:
        print("[server] " + fmt % args)


def main() -> None:
    port = int(os.environ.get("PORT", "8000"))
    server = HTTPServer(("0.0.0.0", port), Handler)
    print(f"listening on http://0.0.0.0:{port}")
    server.serve_forever()


if __name__ == "__main__":
    main()
