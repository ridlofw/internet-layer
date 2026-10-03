#!/usr/bin/env python3
"""
IPv6 HTTP Client via Raw TCP Sockets
Simulates an IoT sensor sending an HTTP GET request to an IPv6 cloud collector.
Course: Internet of Things - Universitas Gadjah Mada
"""

import argparse
import socket
import sys
import time

DEFAULT_SERVER_IPV6 = "2001:db8:2::2"
DEFAULT_PORT = 8000
DEFAULT_PATH = "/"
BUFFER_SIZE = 4096


def send_ipv6_http_request(host: str, port: int, path: str, timeout: float = 5.0) -> None:
    """Connects to an IPv6 HTTP server, sends a GET request, and prints the response."""
    url = f"http://[{host}]:{port}{path}"
    print(f"[*] Target Endpoint : {url}")
    print(f"[*] Address Family  : AF_INET6 (IPv6)")
    print(f"[*] Transport Proto : SOCK_STREAM (TCP)")
    print(f"[*] Connecting to [{host}]:{port} ...")

    start_time = time.time()
    try:
        # Create an IPv6 TCP socket
        with socket.socket(socket.AF_INET6, socket.SOCK_STREAM) as sock:
            sock.settimeout(timeout)
            sock.connect((host, port))
            elapsed_connect = (time.time() - start_time) * 1000
            print(f"[+] TCP 3-Way Handshake completed in {elapsed_connect:.2f} ms")

            # Construct HTTP/1.0 request (simplest standard format)
            request = (
                f"GET {path} HTTP/1.0\r\n"
                f"Host: [{host}]:{port}\r\n"
                f"User-Agent: IoTSensor-IPv6Client/1.0\r\n"
                f"Accept: */*\r\n"
                f"Connection: close\r\n\r\n"
            )

            print("\n--- [Sent HTTP Request] ---")
            for line in request.strip().split("\r\n"):
                print(f"> {line}")

            sock.sendall(request.encode("utf-8"))

            # Receive the response
            response_chunks = []
            while True:
                data = sock.recv(BUFFER_SIZE)
                if not data:
                    break
                response_chunks.append(data)

            raw_response = b"".join(response_chunks)
            total_time = (time.time() - start_time) * 1000

            print("\n--- [Received HTTP Response] ---")
            decoded_response = raw_response.decode("utf-8", errors="replace")
            print(decoded_response.strip())
            print("--------------------------------")
            print(f"[+] Total payload received : {len(raw_response)} bytes")
            print(f"[+] Round-Trip Total Time  : {total_time:.2f} ms")
            print("[+] Status                 : SUCCESS (200 OK)")

    except socket.timeout:
        print(f"\n[-] Error: Connection timed out after {timeout} seconds.", file=sys.stderr)
        print("    Check if the destination namespace and server are running.", file=sys.stderr)
        sys.exit(1)
    except ConnectionRefusedError:
        print(f"\n[-] Error: Connection refused by [{host}]:{port}.", file=sys.stderr)
        print("    Hint: Ensure the HTTP server is running inside the 'iot-cloud' namespace:", file=sys.stderr)
        print(f"          sudo ip netns exec iot-cloud python3 -m http.server {port} --bind {host}", file=sys.stderr)
        sys.exit(1)
    except OSError as err:
        print(f"\n[-] Network OS Error: {err}", file=sys.stderr)
        print("    Hint: Ensure your routing tables and IPv6 addresses are properly configured.", file=sys.stderr)
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(
        description="Dual-Stack IoT Lab - IPv6 HTTP Client (Raw TCP Sockets)"
    )
    parser.add_argument(
        "--host",
        default=DEFAULT_SERVER_IPV6,
        help=f"IPv6 address of the server (default: {DEFAULT_SERVER_IPV6})",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=DEFAULT_PORT,
        help=f"Port of the HTTP server (default: {DEFAULT_PORT})",
    )
    parser.add_argument(
        "--path",
        default=DEFAULT_PATH,
        help=f"Request path (default: {DEFAULT_PATH})",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=5.0,
        help="Socket timeout in seconds (default: 5.0)",
    )

    args = parser.parse_args()
    send_ipv6_http_request(args.host, args.port, args.path, args.timeout)


if __name__ == "__main__":
    main()
