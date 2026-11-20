#!/usr/bin/env python3
"""Generate the ZX Spectrum 48K GTA '82 splash screen (src/splash.asm)
with a 3D drop-shadowed blocky 'GTA '82' logo, 1982 Sinclair rainbow stripes,
city skyline + sports car silhouette, and interactive press-any-key screen.
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Bold 7x7 chunky arcade font for giant 4x-scaled 'GTA '82' logo
GLYPHS = {
    "G": [
        ".#####.",
        "##...##",
        "##.....",
        "##.###.",
        "##..##.",
        "##...##",
        ".#####.",
    ],
    "T": [
        "#######",
        "#######",
        "..###..",
        "..###..",
        "..###..",
        "..###..",
        "..###..",
    ],
    "A": [
        "..###..",
        ".##.##.",
        "##...##",
        "#######",
        "##...##",
        "##...##",
        "##...##",
    ],
    "'": [
        ".##",
        ".##",
        "##.",
        "...",
        "...",
        "...",
        "...",
    ],
    "8": [
        ".#####.",
        "##...##",
        "##...##",
        ".#####.",
        "##...##",
        "##...##",
        ".#####.",
    ],
    "2": [
        ".#####.",
        "##...##",
        "....##.",
        "..###..",
        ".##....",
        "##.....",
        "#######",
    ],
    " ": [
        "..",
        "..",
        "..",
        "..",
        "..",
        "..",
        "..",
    ],
}


def render_logo_bitmap():
    """Render 256x40 pixel-art 'GTA '82' banner with bold bevel/drop-shadow."""
    w, h = 256, 40
    grid = [[0] * w for _ in range(h)]

    text = "GTA '82"
    scale_x = 5
    scale_y = 5

    # Compute total pixel width
    total_w = sum(len(GLYPHS[ch][0]) * scale_x + 4 for ch in text) - 4
    start_x = (w - total_w) // 2
    start_y = 2

    # First draw subtle dithered 3D drop shadow offset (+3, +3)
    cx = start_x
    for ch in text:
        g = GLYPHS[ch]
        gw = len(g[0])
        for gy in range(len(g)):
            for gx in range(gw):
                if g[gy][gx] == "#":
                    for sy in range(scale_y):
                        for sx in range(scale_x):
                            px = cx + gx * scale_x + sx + 3
                            py = start_y + gy * scale_y + sy + 3
                            if 0 <= px < w and 0 <= py < h and ((px + py) & 1) == 0:
                                grid[py][px] = 1
        cx += gw * scale_x + 4

    # Draw solid foreground letters (with 1px dark cutout rim for 3D pop!)
    cx = start_x
    for ch in text:
        g = GLYPHS[ch]
        gw = len(g[0])
        # Cutout dark outline (+1, +1)
        for gy in range(len(g)):
            for gx in range(gw):
                if g[gy][gx] == "#":
                    for sy in range(scale_y):
                        for sx in range(scale_x):
                            px = cx + gx * scale_x + sx + 1
                            py = start_y + gy * scale_y + sy + 1
                            if 0 <= px < w and 0 <= py < h:
                                grid[py][px] = 0
        # Main solid face
        for gy in range(len(g)):
            for gx in range(gw):
                if g[gy][gx] == "#":
                    for sy in range(scale_y):
                        for sx in range(scale_x):
                            px = cx + gx * scale_x + sx
                            py = start_y + gy * scale_y + sy
                            if 0 <= px < w and 0 <= py < h:
                                grid[py][px] = 1
        cx += gw * scale_x + 4

    # Pack into 32 bytes x 40 rows
    out = []
    for y in range(h):
        for bx in range(32):
            b = 0
            for bit in range(8):
                b = (b << 1) | grid[y][bx * 8 + bit]
            out.append(b)
    return out


def render_skyline_car_bitmap():
    """Render 256x32 pixel-art night skyline + speeding side-profile GT car."""
    w, h = 256, 32
    grid = [[0] * w for _ in range(h)]

    # Distant city skyline silhouettes (x0, x1, top_y)
    buildings = [
        (4, 24, 10), (26, 40, 14), (44, 66, 6), (70, 88, 12),
        (92, 114, 8), (118, 134, 15), (140, 164, 5), (168, 186, 11),
        (190, 212, 7), (216, 234, 13), (238, 252, 9),
    ]
    for x0, x1, ty in buildings:
        for y in range(ty, 24):
            for x in range(x0, x1):
                # Roof edge or walls with lit windows
                if y == ty or x == x0 or x == x1 - 1:
                    grid[y][x] = 1
                elif (y % 4) in (1, 2) and ((x - x0) % 4) in (1, 2):
                    grid[y][x] = 1

    # Road horizon line at y = 24, bottom road line at y = 31
    for x in range(w):
        grid[24][x] = 1
        if (x // 8) % 2 == 0:
            grid[28][x] = 1
        grid[31][x] = 1

    # Clear silhouette cutout around speeding GT car (center x=96..160, y=14..27)
    car_art = [
        "..............################..............",  # 14
        "...........###................###...........",  # 15
        ".........##...################...##.........",  # 16
        ".......##..###................###..##.......",  # 17
        "....####################################....",  # 18
        "..########################################..",  # 19
        ".####...############################...####.",  # 20
        "#####..##############################..#####",  # 21
        "############################################",  # 22
        ".#####..####....................####..#####.",  # 23
        "..###..######..................######..###..",  # 24
        ".......######..................######.......",  # 25
        "........####....................####........",  # 26
    ]
    cx0 = (w - len(car_art[0])) // 2
    cy0 = 14
    # Clear padded area behind car so car pops cleanly against skyline
    for dy, row in enumerate(car_art):
        y = cy0 + dy
        for dx, ch in enumerate(row):
            x = cx0 + dx
            if ch == "#":
                for oy in (-1, 0, 1):
                    for ox in (-2, -1, 0, 1, 2):
                        if 0 <= y + oy < h and 0 <= x + ox < w:
                            grid[y + oy][x + ox] = 0
    for dy, row in enumerate(car_art):
        y = cy0 + dy
        for dx, ch in enumerate(row):
            x = cx0 + dx
            if ch == "#":
                grid[y][x] = 1

    # Speed lines trailing left of the GT car!
    for y, x0, x1 in [(18, 48, 92), (20, 32, 88), (22, 56, 94), (24, 40, 84)]:
        for x in range(x0, x1):
            if (x % 3) != 0:
                grid[y][x] = 1

    out = []
    for y in range(h):
        for bx in range(32):
            b = 0
            for bit in range(8):
                b = (b << 1) | grid[y][bx * 8 + bit]
            out.append(b)
    return out


def fmt_db(values, per_line=16):
    lines = []
    for i in range(0, len(values), per_line):
        chunk = values[i : i + per_line]
        lines.append("    db " + ", ".join(f"${v:02X}" for v in chunk))
    return "\n".join(lines)


def main():
    logo = render_logo_bitmap()
    banner = render_skyline_car_bitmap()

    asm = []
    asm.append("; =============================================================================")
    asm.append("; src/splash.asm — AUTO-GENERATED GTA '82 (Grand Theft Auto 0) Splash Screen")
    asm.append("; =============================================================================")
    asm.append("")
    asm.append("ShowSplashScreen:")
    asm.append("    call InitScreen")
    asm.append("")
    asm.append("    ; --- 1. Draw iconic 1982 Sinclair ZX Spectrum rainbow stripes (top-right) ---")
    asm.append("    ; Fill rows 0..1 cols 26..31 with diagonal stripe pattern")
    asm.append("    ld a, 0")
    asm.append(".sp_rb_y:")
    asm.append("    push af")
    asm.append("    ld l, a")
    asm.append("    ld h, high(ScrRowLo)")
    asm.append("    ld a, (hl)")
    asm.append("    add a, 24")
    asm.append("    ld e, a")
    asm.append("    inc h")
    asm.append("    ld d, (hl)")
    asm.append("    ex de, hl")
    asm.append("    ld b, 8")
    asm.append(".sp_rb_x:")
    asm.append("    ld (hl), $FF")
    asm.append("    inc hl")
    asm.append("    djnz .sp_rb_x")
    asm.append("    pop af")
    asm.append("    inc a")
    asm.append("    cp 6")
    asm.append("    jr c, .sp_rb_y")
    asm.append("    ; Color Sinclair 4-stripe rainbow: Red, Yellow, Green, Cyan!")
    asm.append("    ld hl, $5800 + 24")
    asm.append("    ld (hl), $42 : inc hl : ld (hl), $42 : inc hl")
    asm.append("    ld (hl), $46 : inc hl : ld (hl), $46 : inc hl")
    asm.append("    ld (hl), $44 : inc hl : ld (hl), $44 : inc hl")
    asm.append("    ld (hl), $45 : inc hl : ld (hl), $45")
    asm.append("")
    asm.append("    ; Top-left cassette label")
    asm.append("    ld b, 1 : ld c, 0 : ld hl, StrSpTop : call DrawString")
    asm.append("    ld hl, $5800 + 1 : ld b, 22 : ld a, $07")
    asm.append(".sp_ta: ld (hl), a : inc hl : djnz .sp_ta")
    asm.append("")
    asm.append("    ; --- 2. Blit giant 256x40 'GTA '82' 3D logo at Y = 16..55 (rows 2..6) ---")
    asm.append("    ld hl, SplashLogoBmp")
    asm.append("    ld a, 16")
    asm.append("    ld b, 40")
    asm.append("    call BlitSplashStrip")
    asm.append("")
    asm.append("    ; Fiery Vice-82 gradient on 'GTA' (cols 0..16) & Cyan/White on ''82' (cols 17..31)")
    asm.append("    ; Row 2: Yellow GTA / White '82")
    asm.append("    ld hl, $5800 + (2 * 32) : ld b, 17 : ld a, $46 : call FillAttrRun")
    asm.append("    ld b, 15 : ld a, $47 : call FillAttrRun")
    asm.append("    ; Row 3: Yellow GTA / Cyan '82")
    asm.append("    ld hl, $5800 + (3 * 32) : ld b, 17 : ld a, $46 : call FillAttrRun")
    asm.append("    ld b, 15 : ld a, $45 : call FillAttrRun")
    asm.append("    ; Row 4: Red GTA / Cyan '82")
    asm.append("    ld hl, $5800 + (4 * 32) : ld b, 17 : ld a, $42 : call FillAttrRun")
    asm.append("    ld b, 15 : ld a, $45 : call FillAttrRun")
    asm.append("    ; Row 5: Red GTA / Blue-Cyan '82")
    asm.append("    ld hl, $5800 + (5 * 32) : ld b, 17 : ld a, $42 : call FillAttrRun")
    asm.append("    ld b, 15 : ld a, $05 : call FillAttrRun")
    asm.append("    ; Row 6: Magenta GTA / Cyan '82")
    asm.append("    ld hl, $5800 + (6 * 32) : ld b, 17 : ld a, $43 : call FillAttrRun")
    asm.append("    ld b, 15 : ld a, $45 : call FillAttrRun")
    asm.append("")
    asm.append("    ; --- 3. Subtitle: GRAND THEFT AUTO 0 (Row 8) ---")
    asm.append("    ld b, 7 : ld c, 8 : ld hl, StrSpSub : call DrawString")
    asm.append("    ld hl, $5800 + (8 * 32) : ld b, 32 : ld a, $47 : call FillAttrRun")
    asm.append("")
    asm.append("    ; --- 4. Blit 256x32 Night Skyline + Speeding GT Car at Y = 80..111 (rows 10..13) ---")
    asm.append("    ld hl, SplashCarBmp")
    asm.append("    ld a, 80")
    asm.append("    ld b, 32")
    asm.append("    call BlitSplashStrip")
    asm.append("    ; Color skyline Cyan/Blue, speeding GT Car Bright Red ($42) in center!")
    asm.append("    ld hl, $5800 + (10 * 32) : ld b, 32 : ld a, $05 : call FillAttrRun")
    asm.append("    ld hl, $5800 + (11 * 32) : ld b, 32 : ld a, $05 : call FillAttrRun")
    asm.append("    ld hl, $5800 + (12 * 32) : ld b, 12 : ld a, $45 : call FillAttrRun")
    asm.append("    ld b, 8 : ld a, $42 : call FillAttrRun")
    asm.append("    ld b, 12 : ld a, $05 : call FillAttrRun")
    asm.append("    ld hl, $5800 + (13 * 32) : ld b, 12 : ld a, $07 : call FillAttrRun")
    asm.append("    ld b, 8 : ld a, $42 : call FillAttrRun")
    asm.append("    ld b, 12 : ld a, $07 : call FillAttrRun")
    asm.append("")
    asm.append("    ; --- 5. Crime-Spree Tagline, Controls & 1982 Budget Cassette Footer ---")
    asm.append("    ld b, 2 : ld c, 15 : ld hl, StrSpTag : call DrawString")
    asm.append("    ld hl, $5800 + (15 * 32) : ld b, 32 : ld a, $46 : call FillAttrRun")
    asm.append("")
    asm.append("    ld b, 1 : ld c, 17 : ld hl, StrSpCtl1 : call DrawString")
    asm.append("    ld hl, $5800 + (17 * 32) : ld b, 32 : ld a, $07 : call FillAttrRun")
    asm.append("    ld b, 2 : ld c, 18 : ld hl, StrSpCtl2 : call DrawString")
    asm.append("    ld hl, $5800 + (18 * 32) : ld b, 32 : ld a, $45 : call FillAttrRun")
    asm.append("")
    asm.append("    ld b, 3 : ld c, 20 : ld hl, StrSpPress : call DrawString")
    asm.append("")
    asm.append("    ld b, 2 : ld c, 23 : ld hl, StrSpCopy : call DrawString")
    asm.append("    ld hl, $5800 + (23 * 32) : ld b, 32 : ld a, $05 : call FillAttrRun")
    asm.append("")
    asm.append("    ; Brief synth jingle on startup!")
    asm.append("    ld b, 18 : ld c, 64 : call PlayTone")
    asm.append("    ld b, 18 : ld c, 48 : call PlayTone")
    asm.append("    ld b, 24 : ld c, 36 : call PlayTone")
    asm.append("")
    asm.append("    ; Wait for any held key to release first")
    asm.append(".sp_rel:")
    asm.append("    halt")
    asm.append("    call CheckAnyKey")
    asm.append("    jr nz, .sp_rel")
    asm.append("")
    asm.append("    ; Pulse 'PRESS ANY KEY TO START' until player presses any key!")
    asm.append(".sp_wait:")
    asm.append("    halt")
    asm.append("    ld a, (SYS_FRAMES)")
    asm.append("    bit 4, a")
    asm.append("    ld a, $46")
    asm.append("    jr z, .sp_col")
    asm.append("    ld a, $47")
    asm.append(".sp_col:")
    asm.append("    ld hl, $5800 + (20 * 32)")
    asm.append("    ld b, 32")
    asm.append("    call FillAttrRun")
    asm.append("    call CheckAnyKey")
    asm.append("    jr z, .sp_wait")
    asm.append("")
    asm.append("    ; Engine ignition beep!")
    asm.append("    ld b, 22 : ld c, 42 : call PlayTone")
    asm.append("    ld b, 26 : ld c, 28 : call PlayTone")
    asm.append("    ret")
    asm.append("")
    asm.append("; BlitSplashStrip: copies B scanlines (32 bytes each) from HL to screen Y = A")
    asm.append("BlitSplashStrip:")
    asm.append("    ld (.sy), a")
    asm.append(".bss_loop:")
    asm.append("    push bc")
    asm.append("    push hl")
    asm.append("    ld a, (.sy)")
    asm.append("    ld l, a")
    asm.append("    ld h, high(ScrRowLo)")
    asm.append("    ld e, (hl)")
    asm.append("    inc h")
    asm.append("    ld d, (hl)")
    asm.append("    pop hl")
    asm.append("    ld bc, 32")
    asm.append("    ldir")
    asm.append("    ld a, (.sy)")
    asm.append("    inc a")
    asm.append("    ld (.sy), a")
    asm.append("    pop bc")
    asm.append("    djnz .bss_loop")
    asm.append("    ret")
    asm.append(".sy: db 0")
    asm.append("")
    asm.append("; FillAttrRun: fills B bytes at HL with A, leaves HL pointing after run")
    asm.append("FillAttrRun:")
    asm.append("    ld (hl), a")
    asm.append("    inc hl")
    asm.append("    djnz FillAttrRun")
    asm.append("    ret")
    asm.append("")
    asm.append("; Splash Strings (Note: $60 in ZX Spectrum 48K ROM font is the £ symbol!)")
    asm.append('StrSpTop:   db "ZX SPECTRUM 48K EDITION", 0')
    asm.append('StrSpSub:   db "GRAND THEFT AUTO 0", 0')
    asm.append('StrSpTag:   db "6 CHAPTERS - 12 TIMED JOBS!", 0')
    asm.append('StrSpCtl1:  db "WASD/QZOP/ARW:DRIVE  SPC:DRIFT", 0')
    asm.append('StrSpCtl2:  db "C:1P/3P VIEW   M:SOUND ON/OFF", 0')
    asm.append('StrSpPress: db ">> PRESS ANY KEY TO PLAY <<", 0')
    asm.append('StrSpCopy:  db "(C) 1982 SPECGAME  ONLY ", $60, "1.99!", 0')
    asm.append("")
    asm.append("; 256x40 3D Blocky 'GTA '82' Logo Bitmap (1280 bytes)")
    asm.append("SplashLogoBmp:")
    asm.append(fmt_db(logo))
    asm.append("")
    asm.append("; 256x32 Night Skyline + Speeding GT Car Bitmap (1024 bytes)")
    asm.append("SplashCarBmp:")
    asm.append(fmt_db(banner))
    asm.append("")

    (ROOT / "src" / "splash.asm").write_text("\n".join(asm))
    print("Wrote src/splash.asm")


if __name__ == "__main__":
    main()
