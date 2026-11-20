#!/usr/bin/env python3
"""Capture 6 diverse driving angles (close to buildings, diagonal corners,
intersections, park edges, 1P & 3P) to inspect for any visual glitches."""

import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
from zrcp import ZRCP
from verify_game import capture_screen_png


def main():
    out_dir = ROOT / "build" / "debug_shots"
    port = 10013
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
            def wait_frames(n=2):
                start = z.read_memory(0xCB13, 1)[0]
                for _ in range(60):
                    time.sleep(0.05)
                    cur = z.read_memory(0xCB13, 1)[0]
                    if ((cur - start) & 0xFF) >= n:
                        break

            def set_pose(x_tile, x_frac, y_tile, y_frac, angle, speed=0, cam_mode=0):
                z.cmd(f"write-memory 51968 {x_frac}")
                z.cmd(f"write-memory 51969 {x_tile}")
                z.cmd(f"write-memory 51970 {y_frac}")
                z.cmd(f"write-memory 51971 {y_tile}")
                z.cmd(f"write-memory 51972 {angle}")
                z.cmd(f"write-memory 51973 {speed}")
                z.cmd(f"write-memory 51982 {cam_mode}")
                wait_frames(3)

            # 1. Close diagonal view of Red & Yellow buildings on South Blvd
            set_pose(14, 128, 22, 128, 210, 0, 0)
            capture_screen_png(z, out_dir / "d1_diag_downtown.png")

            # 2. Very close up to a building corner (0.6 tile away!)
            set_pose(14, 40, 21, 128, 160, 0, 0)
            capture_screen_png(z, out_dir / "d2_closeup_corner.png")

            # 3. Looking East down Main St intersection
            set_pose(14, 128, 15, 128, 0, 0, 0)
            capture_screen_png(z, out_dir / "d3_east_mainst.png")

            # 4. Neon District (Magenta/Cyan/Yellow tight city streets)
            set_pose(22, 128, 8, 128, 220, 0, 0)
            capture_screen_png(z, out_dir / "d4_neon_district.png")

            # 5. Speedway Oval corner (Green infield + White stadium + Yellow track)
            set_pose(20, 128, 20, 128, 32, 0, 0)
            capture_screen_png(z, out_dir / "d5_speedway_oval.png")

            # 6. Close up in 1st-Person looking diagonally at Plaza & Spire
            set_pose(14, 128, 18, 64, 215, 0, 1)
            capture_screen_png(z, out_dir / "d6_1p_plaza_diag.png")

    finally:
        proc.terminate()
        try:
            proc.wait(timeout=3)
        except subprocess.TimeoutExpired:
            proc.kill()


if __name__ == "__main__":
    main()
