"""Static file server that falls back to index.html for app routes (SPA) and
applies the "/*" block of a Cloudflare Pages style _headers file, if present."""
import functools
import http.server
import os
import sys

root, port = sys.argv[1], int(sys.argv[2])


def load_headers():
    path = os.path.join(root, '_headers')
    headers, in_block = [], False
    if os.path.exists(path):
        for line in open(path):
            if not line.startswith(' '):
                in_block = line.strip() == '/*'
            elif in_block and ':' in line:
                name, value = line.strip().split(':', 1)
                headers.append((name.strip(), value.strip()))
    return headers


class SpaHandler(http.server.SimpleHTTPRequestHandler):
    def send_head(self):
        path = self.translate_path(self.path.split('?', 1)[0])
        if not os.path.exists(path) or self.path.split('?', 1)[0] in ('/_headers', '/_redirects'):
            self.path = '/index.html'
        return super().send_head()

    def end_headers(self):
        for name, value in load_headers():
            self.send_header(name, value)
        super().end_headers()


handler = functools.partial(SpaHandler, directory=root)
http.server.ThreadingHTTPServer(('localhost', port), handler).serve_forever()
