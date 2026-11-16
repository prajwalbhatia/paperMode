from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
import os,json
os.chdir(os.path.dirname(os.path.abspath(__file__)))
class Handler(SimpleHTTPRequestHandler):
 def log_message(self,*args): pass
 def do_POST(self):
  if self.path != '/event': self.send_error(404); return
  data=json.loads(self.rfile.read(int(self.headers.get('Content-Length',0))))
  with open('events.jsonl','a') as f: f.write(json.dumps(data)+'\n')
  self.send_response(204);self.end_headers()
ThreadingHTTPServer(('127.0.0.1',8769),Handler).serve_forever()
