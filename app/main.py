import http.server
import json
import os
import platform
import socketserver

PORT = int(os.environ.get("PORT", 8080))
VERSION = os.environ.get("APP_VERSION", "dev")


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            self._respond(200, {"status": "ok"})
        elif self.path == "/":
            self._respond(200, {
                "service": "ecs-deploy-pipeline",
                "version": VERSION,
                "python": platform.python_version(),
            })
        else:
            self._respond(404, {"error": "not found"})

    def _respond(self, code: int, body: dict) -> None:
        payload = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, fmt, *args):
        print(f"{self.address_string()} - {fmt % args}", flush=True)


if __name__ == "__main__":
    with socketserver.TCPServer(("", PORT), Handler) as httpd:
        httpd.allow_reuse_address = True
        print(f"Listening on :{PORT}", flush=True)
        httpd.serve_forever()
