#!/usr/bin/env python3
"""ZRCP (ZEsarUX Remote Command Protocol) client and inspection helper.

Connects to a running ZEsarUX instance started with:
    zesarux --enable-remoteprotocol --remoteprotocol-port 10000 ...

Can be imported as a library in automated tests or run directly from the CLI.
"""

import argparse
import socket
import sys


class ZRCP:
    """Minimal TCP client for ZEsarUX Remote Command Protocol (ZRCP)."""

    def __init__(self, host="localhost", port=10000, timeout=3.0):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.connect((host, port))
        self.sock.settimeout(timeout)
        self._read_until_prompt()

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()

    def _read_until_prompt(self):
        buf = ""
        while True:
            try:
                chunk = self.sock.recv(4096).decode("utf-8", errors="ignore")
                if not chunk:
                    break
                buf += chunk
                if "command>" in buf or "command@cpu-step>" in buf:
                    break
            except socket.timeout:
                break
        return buf

    def cmd(self, command):
        """Send a raw ZRCP command and return the response text."""
        self.sock.sendall((command + "\n").encode("utf-8"))
        res = self._read_until_prompt()
        for prompt in ("command@cpu-step> ", "command@cpu-step>", "command> ", "command>"):
            if res.endswith(prompt):
                res = res[:-len(prompt)]
                break
        return res.strip()

    def read_memory(self, address, length):
        """Read `length` bytes starting at `address` and return a list of ints."""
        raw = self.cmd(f"hexdump {address} {length}")
        out = []
        for line in raw.splitlines():
            if "H " in line:
                hex_part = line.split("H ", 1)[1].split("|", 1)[0]
                for token in hex_part.split():
                    try:
                        out.append(int(token, 16))
                    except ValueError:
                        pass
        return out[:length]

    def get_registers(self):
        """Return CPU register state string."""
        return self.cmd("get-registers")

    def close(self):
        self.sock.close()


def screen_addr(x_char, y_pixel):
    """Return ZX Spectrum pixel RAM address for char column (0-31) and y (0-191)."""
    hi = 0x40 | (y_pixel & 0x07) | ((y_pixel & 0xC0) >> 3)
    lo = ((y_pixel & 0x38) << 2) | (x_char & 0x1F)
    return (hi << 8) | lo


def attr_addr(x_char, y_char):
    """Return ZX Spectrum attribute RAM address for cell (x_char: 0-31, y_char: 0-23)."""
    return 0x5800 + (y_char * 32) + x_char


def render_pixels(client, x_pixel=0, y_pixel=0, width_px=16, height_px=16):
    """Return an ASCII visualization of a rectangular region of screen RAM."""
    x_char = x_pixel // 8
    chars_wide = max(1, (width_px + 7) // 8)
    lines = []
    for row in range(height_px):
        y = y_pixel + row
        if y >= 192:
            break
        addr = screen_addr(x_char, y)
        data = client.read_memory(addr, chars_wide)
        bits = ""
        for byte in data:
            for bit in range(7, -1, -1):
                bits += "█" if (byte & (1 << bit)) else "."
        lines.append(f"Y={y:03d} [0x{addr:04X}]: {bits[:width_px]}")
    return "\n".join(lines)


def render_attrs(client):
    """Return a 32x24 hex grid of attribute RAM ($5800-$5AFF)."""
    attrs = client.read_memory(0x5800, 768)
    lines = []
    for y in range(24):
        row = attrs[y * 32 : (y + 1) * 32]
        lines.append(f"Row {y:02d}: " + " ".join(f"{b:02X}" for b in row))
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Inspect a running ZEsarUX instance via ZRCP.")
    parser.add_argument("--host", default="localhost", help="ZRCP host (default: localhost)")
    parser.add_argument("--port", type=int, default=10000, help="ZRCP port (default: 10000)")
    parser.add_argument("--cmd", dest="raw_cmd", help="Run a single ZRCP command and print output")
    parser.add_argument("--attrs", action="store_true", help="Dump full 32x24 attribute RAM grid")
    parser.add_argument(
        "--region",
        nargs=4,
        type=int,
        metavar=("X", "Y", "W", "H"),
        help="Render pixel region (X Y W H in pixels)",
    )
    args = parser.parse_args()

    try:
        with ZRCP(host=args.host, port=args.port) as z:
            if args.raw_cmd:
                print(z.cmd(args.raw_cmd))
                return

            print("--- REGISTERS ---")
            print(z.get_registers())

            if args.attrs:
                print("\n--- ATTRIBUTE RAM ($5800-$5AFF) ---")
                print(render_attrs(z))

            if args.region:
                x, y, w, h = args.region
                print(f"\n--- PIXELS ({x},{y}) {w}x{h} ---")
                print(render_pixels(z, x, y, w, h))
            elif not args.attrs:
                print("\n--- ATTRIBUTE RAM ($5800, first 32 bytes) ---")
                first_row = z.read_memory(0x5800, 32)
                print(" ".join(f"{b:02X}" for b in first_row))
                print("\n--- TOP-LEFT PIXELS (16x16) ---")
                print(render_pixels(z, 0, 0, 16, 16))
    except ConnectionRefusedError:
        print(
            f"Could not connect to ZEsarUX ZRCP at {args.host}:{args.port}.\n"
            "Start ZEsarUX first with: make debug",
            file=sys.stderr,
        )
        sys.exit(1)


if __name__ == "__main__":
    main()
