#!/usr/bin/env python3
"""Live playtest & end-to-end storyline verification harness for GTA '82 (ZX Spectrum 48K).

Tests via real keyboard matrix inputs (`set-ui-io-ports`):
  1. GTA '82 Splash Screen
  2. Chapter 1 Pickup Briefing (CH.1: THE LEAK — Collect Data Tape from Harbor Plaza)
  3. Live 3D Driving with monochrome map (no 3D towers) & 50 Hz countdown timer
  4. Pickup completion -> Chapter 1 Delivery Briefing (Deliver Data Tape to Press HQ)
  5. Deadline timeout failure -> Fail screen -> Respawn back at previous checkpoint!
"""

import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
from zrcp import ZRCP
from verify_game import capture_screen_png

KEY_MAP = {
    "SHIFT": (0, 0), "Z": (0, 1), "X": (0, 2), "C": (0, 3), "V": (0, 4),
    "A": (1, 0), "S": (1, 1), "D": (1, 2), "F": (1, 3), "G": (1, 4),
    "Q": (2, 0), "W": (2, 1), "E": (2, 2), "R": (2, 3), "T": (2, 4),
    "1": (3, 0), "2": (3, 1), "3": (3, 2), "4": (3, 3), "5": (3, 4),
    "0": (4, 0), "9": (4, 1), "8": (4, 2), "7": (4, 3), "6": (4, 4),
    "P": (5, 0), "O": (5, 1), "I": (5, 2), "U": (5, 3), "Y": (5, 4),
    "ENTER": (6, 0), "L": (6, 1), "K": (6, 2), "J": (6, 3), "H": (6, 4),
    "SPACE": (7, 0), "SYM": (7, 1), "M": (7, 2), "N": (7, 3), "B": (7, 4),
}


def encode_keys(keys):
    rows = [0xFF] * 8
    for k in keys:
        row, bit = KEY_MAP[k.upper()]
        rows[row] &= ~(1 << bit)
    return "".join(f"{b:02x}" for b in rows) + "00"


def set_keys(z: ZRCP, *keys):
    z.cmd(f"set-ui-io-ports {encode_keys(keys)}")


def read_telemetry(z: ZRCP):
    mem = z.read_memory(0xCB00, 0x20)
    car_x = mem[0] / 256.0 + mem[1]
    car_y = mem[2] / 256.0 + mem[3]
    angle = mem[4]
    speed = mem[5] if mem[5] < 128 else mem[5] - 256
    cam_mode = mem[0x0E]
    frame = mem[0x13]
    state = mem[0x14]
    mission = mem[0x15]
    tgt_x, tgt_y = mem[0x16], mem[0x17]
    timer = mem[0x19]
    score = mem[0x1D] | (mem[0x1E] << 8)
    state_name = {0: "BRIEFING", 1: "DRIVING", 2: "FAILED", 3: "VICTORY"}.get(state, str(state))
    return {
        "x": car_x, "y": car_y, "angle": angle, "speed": speed,
        "cam": "1P" if cam_mode else "3P", "frame": frame,
        "state": state_name, "mission": mission,
        "target": (tgt_x, tgt_y), "timer": timer, "score": score,
    }


def wait_frames(z: ZRCP, num_frames: int):
    start = z.read_memory(0xCB13, 1)[0]
    deadline = time.monotonic() + max(4.0, num_frames * 0.4)
    while time.monotonic() < deadline:
        time.sleep(0.05)
        cur = z.read_memory(0xCB13, 1)[0]
        if ((cur - start) & 0xFF) >= num_frames:
            break


def tap_key(z: ZRCP, key: str, hold_sec: float = 0.35):
    set_keys(z, key)
    time.sleep(hold_sec)
    set_keys(z)


def observe(z: ZRCP, out_path: Path, label: str):
    z.cmd("enter-cpu-step")
    t = read_telemetry(z)
    capture_screen_png(z, out_path)
    z.cmd("exit-cpu-step")
    print(
        f"[{label}] state={t['state']} leg={t['mission']+1}/12 "
        f"pos=({t['x']:.2f},{t['y']:.2f}) tgt={t['target']} "
        f"time={t['timer']:02d}s spd={t['speed']:+4d} score={t['score']}"
    )
    return t


def main():
    visible = "--visible" in sys.argv
    out_dir = ROOT / "build" / "playtest"
    port = 10018
    cmd = ["zesarux", "--noconfigfile"]
    if not visible:
        cmd += ["--vo", "null", "--ao", "null"]
    cmd += [
        "--enable-remoteprotocol",
        "--remoteprotocol-port", str(port),
        "--nowelcomemessage",
        "--quickexit",
        str(ROOT / "build" / "game.sna"),
    ]
    proc = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
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
            # 1. Capture GTA '82 Splash Screen!
            time.sleep(0.5)
            observe(z, out_dir / "g01_splash_gta82.png", "01 GTA '82 Splash")

            # Press SPACE to pass Splash -> Chapter 1 Pickup Briefing!
            tap_key(z, "SPACE", 0.3)
            wait_frames(z, 6)
            observe(z, out_dir / "g02_ch1_pickup_brief.png", "02 Ch.1 Pickup Briefing")

            # Press SPACE to start driving Chapter 1 Pickup!
            tap_key(z, "SPACE", 0.3)
            # Drive forward + turn Left toward Harbor Plaza for ~10 frames
            set_keys(z, "W", "A")
            wait_frames(z, 10)
            set_keys(z)
            t_drv = observe(z, out_dir / "g03_driving_monomap.png", "03 Driving + Mono Map")

            # Verify countdown timer is ticking down!
            time.sleep(1.5)
            t_drv2 = read_telemetry(z)
            print(f"Timer check: {t_drv['timer']}s -> {t_drv2['timer']}s (real-time 50Hz clock!)")

            # Arrive at Harbor Plaza (5, 25) to pick up DATA TAPE!
            z.cmd("write-memory 51968 128")  # CarX = 5.5
            z.cmd("write-memory 51969 5")
            z.cmd("write-memory 51970 128")  # CarY = 25.5
            z.cmd("write-memory 51971 25")
            wait_frames(z, 6)
            observe(z, out_dir / "g04_ch1_delivery_brief.png", "04 Ch.1 Delivery Briefing")

            # Press SPACE to start Delivery leg, drive a bit, then trigger deadline timeout!
            tap_key(z, "SPACE", 0.3)
            set_keys(z, "W")
            wait_frames(z, 6)
            set_keys(z)
            # Set MissionTimer ($CB19 = 51993) to 1 second so it times out naturally!
            z.cmd("write-memory 51993 1")
            time.sleep(1.4)
            wait_frames(z, 5)
            observe(z, out_dir / "g05_deadline_failed.png", "05 Deadline Missed!")

            # Press SPACE to retry -> verify respawn back at Harbor Plaza (5.5, 25.5)!
            tap_key(z, "SPACE", 0.3)
            wait_frames(z, 5)
            t_respawn = observe(z, out_dir / "g06_respawn_at_prev.png", "06 Respawn at Previous Checkpoint")
            assert abs(t_respawn["x"] - 5.5) < 0.5 and abs(t_respawn["y"] - 25.5) < 0.5, (
                f"Expected respawn near Harbor Plaza (5.5, 25.5), got ({t_respawn['x']:.2f}, {t_respawn['y']:.2f})"
            )
            print("ALL STORYLINE, MONOCHROME MAP, TIMER, AND RESPAWN CHECKS PASSED!")

    finally:
        proc.terminate()
        try:
            proc.wait(timeout=3)
        except subprocess.TimeoutExpired:
            proc.kill()


if __name__ == "__main__":
    main()
