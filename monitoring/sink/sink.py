"""Receptor de evidencia para Alertmanager (§10).

No tiene lógica de negocio: recibe el webhook y lo agrega a un JSONL
en evidence/10/. Sirve para demostrar que la notificación sale de
Alertmanager con el payload correcto antes de conectar n8n (§13).
"""
import json
import os
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, HTTPServer

OUT = os.environ.get("SINK_OUT", "/evidence/alertmanager-payloads.jsonl")


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(length)
        try:
            data = json.loads(raw)
        except Exception:
            data = {"raw": raw.decode("utf-8", "replace")}

        alerts = data.get("alerts", []) if isinstance(data, dict) else []
        record = {
            "received_at": datetime.now(timezone.utc).isoformat(),
            "path": self.path,
            "status": data.get("status") if isinstance(data, dict) else None,
            "alerts": alerts,
        }
        with open(OUT, "a", encoding="utf-8") as fh:
            fh.write(json.dumps(record, ensure_ascii=False) + "\n")

        names = ",".join(a.get("labels", {}).get("alertname", "?") for a in alerts)
        print(f"[sink] {self.path} status={record['status']} alertas={len(alerts)} [{names}]", flush=True)

        body = b'{"ok":true}'
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        body = b"alert-sink: POST de Alertmanager en /alertmanager\n"
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    print(f"[sink] escuchando en :8080, escribiendo en {OUT}", flush=True)
    HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
