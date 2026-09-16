#!/usr/bin/env python3
"""端到端测试用的静态服务器：带 CORS 头，并且禁用缓存。

为什么要 CORS 头
----------------
真实世界的 RSS 服务器几乎都不发 `Access-Control-Allow-Origin`，而
`RssService` 设置了自定义 `User-Agent`，使请求成为「非简单请求」，浏览器因此
发起 CORS 预检；服务器不响应预检，请求就被浏览器拦截。所以 Flutter Web 版本
在真实站点上抓不到订阅源 —— 这是架构限制，不是 bug，需要代理层才能解决。

本 fixture 加上 CORS 头，就能让 Web 端跑通完整的解析链路，用于回归测试。

为什么要 no-store
-----------------
不加 `Cache-Control` 时浏览器会按启发式规则缓存响应：改了 feed.xml 之后
应用仍在拿旧内容，很容易被误判成解析 bug。判断方法是看本服务器的日志里
到底有没有收到请求。

用法
----
    python3 tool/e2e_fixture/serve.py [端口]     # 默认 8100

然后在应用里添加 `http://127.0.0.1:8100/feed.xml`（RSS）或
`http://127.0.0.1:8100/atom.xml`（Atom）。
"""

import functools
import http.server
import os
import socketserver
import sys

FIXTURE_DIR = os.path.dirname(os.path.abspath(__file__))


class CorsHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
        # 不要缓存：否则改了 fixture 之后浏览器会拿旧响应，端到端测试看到陈旧数据
        self.send_header("Cache-Control", "no-store, must-revalidate")
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(204)
        self.end_headers()

    def log_message(self, fmt, *args):
        # 日志到 stderr，便于与应用的日志分开看
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))
        sys.stderr.flush()


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8100
    handler = functools.partial(CorsHandler, directory=FIXTURE_DIR)
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("127.0.0.1", port), handler) as httpd:
        print(f"e2e fixture on http://127.0.0.1:{port}/", flush=True)
        print(f"  RSS : http://127.0.0.1:{port}/feed.xml", flush=True)
        print(f"  Atom: http://127.0.0.1:{port}/atom.xml", flush=True)
        httpd.serve_forever()


if __name__ == "__main__":
    main()