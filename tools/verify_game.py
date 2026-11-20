#!/usr/bin/env python3
"""Headless ZEsarUX verification & ZX Spectrum screenshot capture tool.

Captures exact 2x-scaled (512x384) PNG screenshots of the ZX Spectrum 48K screen
($4000-$5AFF) via ZRCP, measures real Z80 FPS, and tests 3rd-person, 1st-person,
driving movement, and off-road park rendering.
"""

import struct
import subprocess
import sys
import time
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
from zrcp import ZRCP

# Authentic ZX Spectrum 48K RGB palette (normal + bright)
PALETTE_NORMAL = [
    (0, 0, 0),        # 0 Black
    (0, 0, 215),      # 1 Blue
    (215, 0, 0),      # 2 Red
    (215, 0, 215),    # 3 Magenta
    (0, 215, 0),      # 4 Green
    (0, 215, 215),    # 5 Cyan
    (215, 215, 0),    # 6 Yellow
    (215, 215, 215),  # 7 White
]

PALETTE_BRIGHT = [
    (0, 0, 0),        # 0 Black
    (0, 0, 255),      # 1 Bright Blue
    (255, 0, 0),      # 2 Bright Red
    (255, 0, 255),    # 3 Bright Magenta
    (0, 255, 0),      # 4 Bright Green
    (0, 255, 255),    # 5 Bright Cyan
    (255, 255, 0),    # 6 Bright Yellow
    (255, 255, 255),  # 7 Bright White
]


def write_png(path: Path, width: int, height: int, rgb_bytes: bytes):
    """Write an RGB PNG file using only Python stdlib (zlib + struct)."""
    def chunk(tag: bytes, data: bytes) -> bytes:
        crc = zlib.crc32(tag + data) & 0xFFFFFFFF
        return struct.pack("!I", len(data)) + tag + data + struct.pack("!I", crc)

    raw = bytearray()
    stride = width * 3
    for y in range(height):
        raw.append(0)  # Filter type 0 (None)
        raw.extend(rgb_bytes[y * stride : (y + 1) * stride])

    ihdr = struct.pack("!IIBBBBB", width, height, 8, 2, 0, 0, 0)
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", zlib.compress(bytes(raw), 6))
        + chunk(b"IEND", b"")
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)


def read_memory_chunked(z: ZRCP, start: int, total: int, chunk_size: int = 512):
    data = []
    addr = start
    while len(data) < total:
        n = min(chunk_size, total - len(data))
        part = z.read_memory(addr, n)
        data.extend(part)
        addr += n
    return data[:total]


def capture_screen_png(z: ZRCP, out_path: Path, scale: int = 2):
    # Pause CPU briefly for tear-free atomic snapshot? No, let's see if ZRCP reads cleanly!
    pixels = read_memory_chunked(z, 0x4000, 6144, chunk_size=512)
    attrs = read_memory_chunked(z, 0x5800, 768, chunk_size=256)

    w, h = 256 * scale, 192 * scale
    rgb = bytearray(w * h * 3)

    for y in range(192):
        hi = ((y & 0xC0) >> 3) | (y & 0x07)
        lo = (y & 0x38) << 2
        row_off = (hi << 8) | lo
        attr_row = (y // 8) * 32

        for cx in range(32):
            byte = pixels[row_off + cx]
            attr = attrs[attr_row + cx]
            ink = attr & 0x07
            paper = (attr >> 3) & 0x07
            bright = (attr >> 6) & 0x01
            pal = PALETTE_BRIGHT if bright else PALETTE_NORMAL
            c_ink = pal[ink]
            c_pap = pal[paper]

            for bit in range(8):
                col = c_ink if (byte & (0x80 >> bit)) else c_pap
                px = (cx * 8 + bit) * scale
                py = y * scale
                for sy in range(scale):
                    base = ((py + sy) * w + px) * 3
                    for sx in range(scale):
                        rgb[base + sx * 3] = col[0]
                        rgb[base + sx * 3 + 1] = col[1]
                        rgb[base + sx * 3 + 2] = col[2]

    write_png(out_path, w, h, bytes(rgb))
    print(f"Saved screenshot: {out_path}")


def main():
    out_dir = ROOT / "build" / "shots"
    port = 10012
    proc = subprocess.Popen(
        [
            "zesarux",
            "--noconfigfile",
            "--vo", "null",
            "--ao", "null",
            "--enable-remoteprotocol",
            "--remoteprotocol-port", str(port),
            "--nowelcomemessage",
            "--quickexit",
            str(ROOT / "build" / "game.sna"),
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    try:
        # Wait for ZRCP to come online
        z = None
        for _ in range(30):
            time.sleep(0.2)
            try:
                z = ZRCP(port=port, timeout=3.0)
                break
            except ConnectionRefusedError:
                pass
        if z is None:
            raise RuntimeError("Could not connect to ZEsarUX ZRCP")

        with z:
            time.sleep(0.5)
            # Measure real FPS via FrameCounter ($CB13)
            f0 = z.read_memory(0xCB13, 1)[0]
            t0 = time.monotonic()
            time.sleep(2.0)
            f1 = z.read_memory(0xCB13, 1)[0]
            t1 = time.monotonic()
            df = (f1 - f0) & 0xFF
            fps = df / (t1 - t0)
            print(f"Registers: {z.get_registers()}")
            print(f"FrameCounter delta: {df} frames in {t1-t0:.2f}s -> {fps:.1f} FPS!")

            # Helper: wait until FrameCounter advances by at least 2 frames
            def wait_frames(n=2):
                start = z.read_memory(0xCB13, 1)[0]
                for _ in range(50):
                    time.sleep(0.05)
                    cur = z.read_memory(0xCB13, 1)[0]
                    if ((cur - start) & 0xFF) >= n:
                        break

            # Shot 1: Initial 3rd-Person Chase View on South Grand Boulevard
            capture_screen_png(z, out_dir / "01_start_3p.png")

            # Shot 2: 3P View approaching Central Plaza & turning NNE toward Spire & Sun!
            z.cmd("write-memory 51968 128")  # $CB00 CarX lo = 128 (15.5)
            z.cmd("write-memory 51969 15")   # $CB01 CarX hi = 15
            z.cmd("write-memory 51970 128")  # $CB02 CarY lo = 128 (19.5)
            z.cmd("write-memory 51971 19")   # $CB03 CarY hi = 19
            z.cmd("write-memory 51972 204")  # $CB04 CarAngle = 204 (NNE)
            z.cmd("write-memory 51973 80")   # $CB05 CarSpeed = 80
            wait_frames(2)
            capture_screen_png(z, out_dir / "02_plaza_3p_driving.png")

            # Shot 3: 1st-Person Cockpit View on Grand Blvd (CamMode = 1!)
            z.cmd("write-memory 51982 1")    # $CB0E CamMode = 1 (1P Cockpit!)
            z.cmd("write-memory 51968 128")  # CarX = 15.5
            z.cmd("write-memory 51969 15")
            z.cmd("write-memory 51970 128")  # CarY = 23.5
            z.cmd("write-memory 51971 23")
            z.cmd("write-memory 51972 192")  # CarAngle = 192 (North)
            z.cmd("write-memory 51973 64")   # Speed = 64
            wait_frames(2)
            capture_screen_png(z, out_dir / "03_cockpit_1p.png")

            # Shot 4: Off-road in Central Park (3P view, lush green grass + trees!)
            z.cmd("write-memory 51982 0")    # 3P View
            z.cmd("write-memory 51968 128")  # CarX = 7.5
            z.cmd("write-memory 51969 7")
            z.cmd("write-memory 51970 128")  # CarY = 9.5
            z.cmd("write-memory 51971 9")
            z.cmd("write-memory 51972 180")  # Facing NNW across green park!
            z.cmd("write-memory 51973 48")
            wait_frames(2)
            capture_screen_png(z, out_dir / "04_central_park_offroad.png")

    finally:
        proc.terminate()
        try:
            proc.wait(timeout=3)
        except subprocess.TimeoutExpired:
            proc.kill()


if __name__ == "__main__":
    main()
