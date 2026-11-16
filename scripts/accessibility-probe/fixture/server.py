"""Loopback-only fixture server; no browser automation or external data collection."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import json, threading, time
log = Path('.build/accessibility-probe/fixture-events.jsonl')
lock = threading.Lock()
class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args): pass
    def do_GET(self):
        if self.path.split('?')[0] != '/':
            self.send_error(404); return
        body = Path(__file__).with_name('index.html').read_bytes()
        self.send_response(200); self.send_header('Content-Type','text/html'); self.send_header('Cache-Control','no-store'); self.end_headers(); self.wfile.write(body)
    def do_POST(self):
        if self.path != '/event' or int(self.headers.get('Content-Length', '0')) > 4096:
            self.send_error(400); return
        data = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        with lock:
            with log.open('a') as f: f.write(json.dumps({'received':time.time(), **data})+'\n')
        self.send_response(204); self.end_headers()
server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
print(f'http://127.0.0.1:{server.server_port}/', flush=True)
server.serve_forever()
