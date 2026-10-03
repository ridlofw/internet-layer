#!/usr/bin/env python3
"""
IPv6 HTTP Server for IoT Cloud Collector
Listens on an IPv6 address and serves IoT sensor telemetry endpoints.
Course: Internet of Things - Universitas Gadjah Mada
"""

import argparse
from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import socket
import sys
import time

DEFAULT_BIND_IPV6 = "2001:db8:2::2"
DEFAULT_PORT = 8000


class V6HTTPServer(HTTPServer):
    """Custom HTTPServer configured specifically for IPv6 AF_INET6 address family."""
    address_family = socket.AF_INET6


class IoTCloudRequestHandler(BaseHTTPRequestHandler):
    """HTTP Request Handler providing simulated IoT collector responses."""

    def do_GET(self):
        client_ip = self.client_address[0]
        client_port = self.client_address[1]
        print(f"[+] Incoming Request from [{client_ip}]:{client_port} -> Path: '{self.path}'")

        if self.path == "/api/status" or self.path == "/status":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Server", "IoTCloudCollector/1.0 (IPv6)")
            self.end_headers()

            payload = {
                "status": "ONLINE",
                "collector": "iot-cloud",
                "transport": "IPv6 / TCP",
                "timestamp": time.time(),
                "server_address": DEFAULT_BIND_IPV6,
                "message": "IoT Network Layer dual-stack verification successful."
            }
            self.wfile.write(json.dumps(payload, indent=2).encode("utf-8"))
        else:
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Server", "IoTCloudCollector/1.0 (IPv6)")
            self.end_headers()

            html = f"""<!DOCTYPE html>
<html>
<head><title>IoT Cloud Collector (IPv6)</title></head>
<body style="font-family: sans-serif; padding: 2rem;">
  <h1>🌐 IoT Cloud Collector Server</h1>
  <p><strong>Status:</strong> Active & Listening on IPv6</p>
  <p><strong>Your IP:</strong> <code>[{client_ip}]</code></p>
  <p><strong>Server Address:</strong> <code>[{DEFAULT_BIND_IPV6}]:{DEFAULT_PORT}</code></p>
  <hr/>
  <p><em>Internet Layer Experiment 5 - Universitas Gadjah Mada</em></p>
</body>
</html>
"""
            self.wfile.write(html.encode("utf-8"))

    def log_message(self, format, *args):
        # Clean logging format with timestamp
        sys.stdout.write(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] {self.address_string()} - {format % args}\n")


def run_server(bind_ip: str, port: int):
    print("=" * 60)
    print("[*] Starting IoT IPv6 Cloud Server")
    print(f"[*] Listening Address : [{bind_ip}]:{port}")
    print("[*] Protocol          : IPv6 / TCP (HTTP/1.0)")
    print("=" * 60)
    print("Press Ctrl+C to terminate.")

    try:
        server = V6HTTPServer((bind_ip, port), IoTCloudRequestHandler)
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[*] Shutting down server gracefully...")
    except OSError as err:
        print(f"\n[-] Bind Error: {err}", file=sys.stderr)
        print("    Hint: Ensure the network namespace has the assigned IPv6 address:", file=sys.stderr)
        print(f"          sudo ip -n iot-cloud -6 addr add {bind_ip}/64 dev c0", file=sys.stderr)
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="IoT Cloud Collector IPv6 HTTP Server")
    parser.add_argument(
        "--bind",
        default=DEFAULT_BIND_IPV6,
        help=f"IPv6 address to bind (default: {DEFAULT_BIND_IPV6})",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=DEFAULT_PORT,
        help=f"Listening port (default: {DEFAULT_PORT})",
    )
    args = parser.parse_args()

    run_server(args.bind, args.port)


if __name__ == "__main__":
    main()
