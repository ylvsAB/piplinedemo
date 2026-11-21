import json
import threading
import urllib.error
import urllib.request
from http.server import HTTPServer

import pytest

from pipeline_demo.server import Handler


@pytest.fixture()
def base_url():
    server = HTTPServer(("127.0.0.1", 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        yield f"http://127.0.0.1:{server.server_port}"
    finally:
        server.shutdown()
        server.server_close()


def test_health_returns_ok(base_url):
    with urllib.request.urlopen(f"{base_url}/health") as resp:
        assert resp.status == 200
        assert json.loads(resp.read())["status"] == "ok"


def test_add_api(base_url):
    with urllib.request.urlopen(f"{base_url}/api/add?a=2&b=3") as resp:
        assert json.loads(resp.read())["result"] == 5


def test_add_api_rejects_bad_params(base_url):
    with pytest.raises(urllib.error.HTTPError) as exc:
        urllib.request.urlopen(f"{base_url}/api/add?a=x")
    assert exc.value.code == 400
