; =============================================================================
; src/render.asm — Fast 32-Col Sky/Skyline, 8-Band Road/Grass Ground Caster,
;                  Variable-Height 3D Textured Buildings, 3D Beacon,
;                  Unrolled Blitter, and 1P/3P Car Overlays
; =============================================================================

; -----------------------------------------------------------------------------
; RenderFrame
; Full 3D viewport render pipeline -> off-screen buffer -> blit -> 1P/3P overlay
; -----------------------------------------------------------------------------
RenderFrame:
    call RenderSky              ; Clear sky, scrolling hills/skyline & sun
    call RenderGround           ; Fast 8-band perspective roads, grass, plaza
    call RenderWalls            ; Fast 32-col variable-height textured 3D buildings
    halt                        ; Sync right before blit -> zero flicker, tear-free!
    call BlitViewport           ; Interleaved VBUF -> ZX Spectrum Screen
    call RenderCarOverlay       ; Full 1:1 res 3P Chase Car or 1P Hood/Pillars
    ret

; -----------------------------------------------------------------------------
; RenderSky
; Clears sky half of VBUF_PX (rows 0..31 = 1024 B), fills sky VBUF_ATTR
; (rows 0..7 = 256 B) with ATTR_SKY, draws scrolling distant hills/skyline
; and golden sun (seamless normal-blue paper, zero box halo!).
; -----------------------------------------------------------------------------
RenderSky:
    ; Clear VBUF_PX rows 0..31 (1024 bytes)
    ld hl, VBUF_PX
    ld de, VBUF_PX + 1
    ld bc, 1023
    ld (hl), 0
    ldir

    ; Fill VBUF_ATTR rows 0..7 (256 bytes) with ATTR_SKY (Blue paper, Cyan ink)
    ld hl, VBUF_ATTR
    ld de, VBUF_ATTR + 1
    ld bc, 255
    ld (hl), ATTR_SKY
    ldir

    ; --- Draw Scrolling Distant Mountains / City Skyline ---
    ld a, (CamAngle)
    sub 31
    ld c, a                     ; C = ray angle (+2 per column)
    ld b, 0                     ; B = byte column 0..31
.sky_col_loop:
    push bc

    ; Lookup skyline height (1..10 rows above horizon)
    ld l, c
    ld h, high(SkylineTable)
    ld a, (hl)
    ld e, a                     ; E = hill height

    ; Skip skyline if a building in this column is already taller!
    ld l, b
    ld h, high(RAY_HEIGHT)
    ld a, low(RAY_HEIGHT)
    add a, b
    ld l, a
    ld a, (hl)
    cp e
    jr nc, .sky_skip_col        ; Building baseH >= skyline -> roofH is way taller!

    ; Draw dithered cyan mountain silhouette upward from row 31
    ld hl, VBUF_PX + (31 * 32)
    ld a, l
    or b
    ld l, a
    ld b, e                     ; Loop count = height
    ld de, -32
.sky_row_loop:
    bit 0, b
    ld a, %10101010
    jr z, .sky_st
    ld a, %01010101
.sky_st:
    ld (hl), a
    add hl, de
    djnz .sky_row_loop

.sky_skip_col:
    pop bc
    inc c
    inc c
    inc b
    ld a, b
    cp 32
    jr c, .sky_col_loop

    ; --- Draw Scrolling Golden Sun (anchored at world angle 216 = NNE) ---
    ld a, (CamAngle)
    sub 31
    ld b, a
    ld a, 216
    sub b
    cp 60
    ret nc
    srl a                       ; Byte column 0..29
    ld c, a

    ld hl, VBUF_PX + (6 * 32)
    ld b, 0
    add hl, bc
    ld de, SunBitmap
    ld b, 8
.sun_px_loop:
    ld a, (de)
    ld (hl), a
    inc de
    inc hl
    ld a, (de)
    ld (hl), a
    inc de
    push de
    ld de, 31
    add hl, de
    pop de
    djnz .sun_px_loop

    ; Seamless Blue paper + Yellow ink ($0E, same bright=0 as sky!)
    ld hl, VBUF_ATTR + (1 * 32)
    ld b, 0
    add hl, bc
    ld (hl), ATTR_SKY_SUN
    inc hl
    ld (hl), ATTR_SKY_SUN
    ld de, 31
    add hl, de
    ld (hl), ATTR_SKY_SUN
    inc hl
    ld (hl), ATTR_SKY_SUN
    add hl, de
    ld (hl), ATTR_SKY_SUN
    inc hl
    ld (hl), ATTR_SKY_SUN
    ret

SunBitmap:
    db %00000111, %11100000
    db %00011111, %11111000
    db %00111111, %11111100
    db %01111111, %11111110
    db %01111111, %11111110
    db %00111111, %11111100
    db %00011111, %11111000
    db %00000111, %11100000

; -----------------------------------------------------------------------------
; RenderGround
; Fast 8-band perspective ground/road/grass/plaza caster (bands 0..7 = exact
; Spectrum character rows 8..15 below horizon!).
; Each band writes 4 buffer rows (= 8 screen scanlines) & 1 attribute cell.
; -----------------------------------------------------------------------------
RenderGround:
    ld a, (CamAngle)
    ld l, a
    ld h, high(SinTable)
    ld a, (hl)
    ld (GndSin), a

    ld a, (CamAngle)
    ld l, a
    ld h, 0
    ld de, CosTable
    add hl, de
    ld a, (hl)
    ld (GndCos), a

    ld hl, VBUF_PX + (32 * 32)  ; Start at row 32 (horizon)
    ld (GndBufPtr), hl
    ld hl, VBUF_ATTR + (8 * 32) ; Start at attr char row 8
    ld (GndAttrPtr), hl
    xor a
    ld (GndBand), a

.band_loop:
    ; Look up d = RowDistDiv16[GndBand] (8 bands: 0..7)
    ld a, (GndBand)
    ld e, a
    ld d, 0
    ld hl, RowDistDiv16
    add hl, de
    ld d, (hl)

    ; stepX = MulU8xS8_Shr7(d, -GndSin)
    push de
    ld a, (GndSin)
    neg
    ld e, a
    ld a, d
    call MulU8xS8_Shr7
    ld (GndStepX), hl
    pop de

    ; stepY = MulU8xS8_Shr7(d, GndCos)
    ld a, (GndCos)
    ld e, a
    ld a, d
    call MulU8xS8_Shr7
    ld (GndStepY), hl

    ; startX = CamX + ((stepY - stepX) << 4)
    ld de, (GndStepX)
    or a
    sbc hl, de
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    ld de, (CamX)
    add hl, de
    ld (GndCurX), hl

    ; startY = CamY - ((stepX + stepY) << 4)
    ld hl, (GndStepX)
    ld de, (GndStepY)
    add hl, de
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    ex de, hl
    ld hl, (CamY)
    or a
    sbc hl, de
    ld (GndCurY), hl

    ; Minimum row inside this band: bandRow = GndBand * 4
    ld a, (GndBand)
    add a, a
    add a, a
    add a, 4                    ; Top-to-bottom end of this band = (band+1)*4
    ld (.bandEnd), a

    ; --- Inner loop over 32 columns ---
    ld b, 0
.gnd_col_loop:
    push bc

    ; Fast occlusion skip: if RAY_HEIGHT[col] >= (band+1)*4, wall covers whole cell!
    ld h, high(RAY_HEIGHT)
    ld a, low(RAY_HEIGHT)
    add a, b
    ld l, a
    ld a, (.bandEnd)
    cp (hl)
    jp z, .gnd_skip
    jp c, .gnd_skip

    ; Look up ground tile at (GndCurX_hi, GndCurY_hi)
    ld hl, (GndCurX)
    ld d, h                     ; D = mapX
    ld a, d
    cp 32
    jr nc, .gnd_default_road
    ld hl, (GndCurY)
    ld e, h                     ; E = mapY
    ld a, e
    cp 32
    jr nc, .gnd_default_road

    rrca
    rrca
    rrca
    ld h, a
    and $E0
    or d
    ld l, a
    ld a, h
    and $03
    or $D0
    ld h, a
    ld a, (hl)

    ; Dispatch ground tile -> C = pixel pattern row 0/2, D = pixel pattern row 1/3, E = attr
    or a
    jr z, .gnd_default_road     ; Clean black asphalt road
    dec a
    jr z, .gnd_default_road     ; Clean black boulevard / speedway asphalt
    dec a
    jr z, .tile_grass
    dec a
    jr z, .tile_plaza
    ; If ground sample barely grazes a Park Tree (tile 9), draw grass skirt!
    cp 6                        ; original tile 9 -> after 3 decs is 6
    jr z, .tile_grass

.gnd_default_road:
    ld c, 0
    ld d, 0
    ld e, ATTR_ROAD
    jr .write_gnd_cell

.tile_grass:
    ; Lush green parkland grass with subtle moving grass blades!
    ld e, ATTR_GRASS
    ld a, (GndCurX)
    ld hl, GndCurY
    xor (hl)
    and $60
    ld c, 0
    ld d, 0
    jr nz, .write_gnd_cell
    ld c, %00100000
    ld d, %00000100
    jr .write_gnd_cell

.tile_plaza:
    ; Downtown paved stone plaza: crisp Cyan cobblestone texture on Black
    ld e, ATTR_PLAZA
    ld c, %01000100
    ld d, %00000000
    ld a, (GndBand)
    cp 1
    jr c, .write_gnd_cell
    ld a, (GndCurX)
    sub $68
    cp $30
    jr nc, .write_gnd_cell
    ld a, (GndCurY)
    sub $68
    cp $30
    jr nc, .write_gnd_cell
    ld c, %11011011
    ld d, %01000100

.write_gnd_cell:
    ; Write 4 buffer rows (band*4 + 0..3) at column B in VBUF_PX
    ld hl, (GndBufPtr)
    ld a, b
    add a, l
    ld l, a                     ; GndBufPtr is 128-byte aligned -> no carry!
    ld (hl), c
    ld a, l
    add a, 32
    ld l, a
    ld (hl), d
    ld a, l
    add a, 32
    ld l, a
    ld (hl), c
    ld a, l
    add a, 32
    ld l, a
    ld (hl), d

    ; Write attribute E to VBUF_ATTR
    ld hl, (GndAttrPtr)
    ld a, b
    add a, l
    ld l, a
    ld (hl), e

.gnd_skip:
    ld hl, (GndCurX)
    ld de, (GndStepX)
    add hl, de
    ld (GndCurX), hl

    ld hl, (GndCurY)
    ld de, (GndStepY)
    add hl, de
    ld (GndCurY), hl

    pop bc
    inc b
    ld a, b
    cp 32
    jp c, .gnd_col_loop

    ; Advance GndBufPtr by 128 bytes (4 buffer rows) and GndAttrPtr by 32 bytes
    ld hl, (GndBufPtr)
    ld de, 128
    add hl, de
    ld (GndBufPtr), hl

    ld hl, (GndAttrPtr)
    ld de, 32
    add hl, de
    ld (GndAttrPtr), hl

    ld hl, GndBand
    inc (hl)
    ld a, (hl)
    cp 8
    jp c, .band_loop
    ret

.bandEnd: db 0

; -----------------------------------------------------------------------------
; RenderWalls
; Ultra-fast 32-column variable-height 3D building renderer!
; Each building type has its own realistic roof height multiplier:
;   - Cyan Glass (5) & White Tower (7): 2.5x tall skyscrapers!
;   - Red Brick (4), Yellow (6), Magenta Neon (8): 2.0x city buildings!
;   - Park Trees (9): 1.5x tall foliage
;   - Highway Guardrail (10): 0.5x low barrier (skyline visible over it!)
; Base stays locked at 32 + baseH - 1 for 100% flush ground contact!
; -----------------------------------------------------------------------------
RenderWalls:
    xor a
    ld (RenCol), a

.wall_col_loop:
    ld a, (RenCol)
    ld e, a

    ; Read baseH = RAY_HEIGHT[col]
    ld h, high(RAY_HEIGHT)
    ld a, low(RAY_HEIGHT)
    add a, e
    ld l, a
    ld a, (hl)
    or a
    jp z, .next_wall_col        ; Missed ray -> skip!
    ld b, a                     ; B = baseH (1..32)

    ; Read tile = RAY_TILE[col] (low bits = 4..10, bit 7 = shaded side)
    ld a, low(RAY_TILE)
    add a, e
    ld l, a
    ld c, (hl)                  ; C = tile | side

    ; Compute tileIndex = (tile & $0F) - 4  (0..6)
    ld a, c
    and $0F
    sub TILE_SOLID_MIN
    jr nc, .ti_ok1
    xor a
.ti_ok1:
    cp 7
    jr c, .ti_ok2
    ld a, 6
.ti_ok2:
    ld (.tileIdx), a

    ; --- Compute Variable Roof Height (roofH in 1..32) from baseH (B) & tileIdx ---
    ; Type 0 (Red Brick), 2 (Yellow), 4 (Magenta): roofH = baseH * 2
    ; Type 1 (Cyan Skyscraper), 3 (White Tower):   roofH = baseH * 2 + baseH/2 (2.5x!)
    ; Type 5 (Trees):                              roofH = baseH + baseH/2 (1.5x)
    ; Type 6 (Guardrail):                          roofH = max(1, baseH / 2) (0.5x!)
    cp 6
    jr z, .h_guardrail
    cp 5
    jr z, .h_trees
    cp 1
    jr z, .h_skyscraper
    cp 3
    jr z, .h_skyscraper
    ; Standard 2.0x building
    ld a, b
    add a, b
    jr .clamp_roof
.h_skyscraper:
    ld a, b
    srl a                       ; baseH / 2
    add a, b                    ; 1.5x
    jr c, .roof_max
    add a, b                    ; 2.5x!
    jr c, .roof_max
    jr .clamp_roof
.h_trees:
    ld a, b
    srl a
    add a, b                    ; 1.5x
    jr .clamp_roof
.h_guardrail:
    ld a, b
    srl a
    or a
    jr nz, .clamp_roof
    inc a
    jr .clamp_roof
.roof_max:
    ld a, 32
.clamp_roof:
    cp 33
    jr c, .roof_ok
    ld a, 32
.roof_ok:
    ; topY = 32 - roofH (0..31), botY = 31 + baseH (32..63)
    ld d, a                     ; D = roofH
    ld a, 32
    sub d
    ld (.topY), a
    ld a, 31
    add a, b
    ld (.botY), a

    ; --- Set Column Attributes in VBUF_ATTR (ZERO roofline or horizontal clash!) ---
    ld a, (.tileIdx)
    ld hl, WallInkTable
    ld e, a
    ld d, 0
    add hl, de
    ld a, (hl)                  ; A = Ink (2..7)
    ; Bright if sunlit (bit 7 of C == 0) AND not distant fog (baseH >= 5)
    bit 7, c
    jr nz, .no_bright
    ld e, a
    ld a, b                     ; B = baseH
    cp 5
    ld a, e
    jr c, .no_bright
    or $40                      ; BRIGHT 1!
.no_bright:
    ld (.wallAttr), a

    ; Compute topCh = topY >> 2 (0..7), botCh = botY >> 2 (8..15)
    ld a, (.topY)
    srl a
    srl a
    ld d, a                     ; D = topCh
    ld a, (.botY)
    srl a
    srl a
    ld e, a                     ; E = botCh

    ; HL = VBUF_ATTR + topCh * 32 + RenCol
    ld l, d
    ld h, 0
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    ld a, (RenCol)
    or l
    ld l, a
    ld a, h
    add a, high(VBUF_ATTR)
    ld h, a

    ; First char row (topCh): if wall starts mid-cell, blend with Sky PAPER 1 ($08, normal bright=0)!
    ld a, (.topY)
    and $03
    ld a, (.wallAttr)
    jr z, .top_full
    and $07                     ; Clear BRIGHT bit so PAPER 1 matches sky seamlessly!
    or $08                      ; PAPER 1 (Blue Sky) + Wall Ink!
.top_full:
    ld (hl), a

    ; Middle char rows (topCh + 1 .. botCh - 1): PAPER 0 (Black) + Wall Ink + Bright
    ld a, e
    sub d                       ; Always >= 1 since topCh <= 7 and botCh >= 8
    jr z, .attr_done
    dec a                       ; Count of strictly middle rows = (botCh - topCh - 1)
    push de
    ld de, 32
    jr z, .attr_bot_cell
    ld b, a
    ld a, (.wallAttr)
.attr_loop:
    add hl, de
    ld (hl), a
    djnz .attr_loop

.attr_bot_cell:
    ; Last char row (botCh): if wall ends mid-cell on GREEN GRASS, blend PAPER 4 + Wall Ink!
    add hl, de
    ld a, (.botY)
    and $03
    cp $03
    jr z, .bot_full_cell
    ld a, (hl)                  ; Inspect existing ground attribute from RenderGround
    cp ATTR_GRASS               ; Was this cell lush Green Grass ($20)?
    jr nz, .bot_full_cell
    ld a, (.wallAttr)
    and $07                     ; Extract Wall Ink (2..7)
    cp 4                        ; Green Park Tree (Ink 4) on Green Grass?
    jr nz, .bot_grass_ink
    xor a                       ; Use Black ink ($00) for dark tree base/shadow on grass!
.bot_grass_ink:
    or $20                      ; PAPER 4 (Green Grass) + Wall Ink! Zero black bar!
    ld (hl), a
    jr .attr_pop
.bot_full_cell:
    ld a, (.wallAttr)
    ld (hl), a
.attr_pop:
    pop de
.attr_done:

    ; --- Compute solid fascia thresholds for shared Top & Bottom cells ---
    ; topSolidEnd: rows < topSolidEnd draw solid $FF (prevents blue sky leaking in windows!)
    ld a, (.topY)
    ld b, a
    and $03
    jr z, .top_exact
    ld a, b
    add a, 3
    and $FC                     ; End of topCh cell (next multiple of 4)
    jr .set_top_end
.top_exact:
    ld a, b
    inc a                       ; Just 1-row cornice at topY
.set_top_end:
    ld (.topSolidEnd), a

    ; botSolidStart: rows >= botSolidStart draw solid $FF (prevents grass leaking in base!)
    ld a, (.botY)
    ld b, a
    and $03
    cp $03
    jr z, .bot_exact
    ld a, b
    and $FC                     ; Start of botCh cell
    jr .set_bot_start
.bot_exact:
    ld a, b                     ; Just 1-row curb at botY
.set_bot_start:
    ld (.botSolidStart), a

    ; --- Ultra-Fast Unmasked 8-Pixel Wall Strip Pixel Loop ---
    ld a, (.tileIdx)
    add a, a
    add a, a                    ; * 4
    bit 7, c                    ; Shaded side?
    jr z, .lit_p
    add a, 28
.lit_p:
    ld e, a
    ld d, 0
    ld hl, WallPatterns
    add hl, de
    push hl
    pop ix                      ; IX points to 4-byte pattern [p0, p1, p2, p3]

    ; Compute starting buffer pointer: VBUF_PX + topY * 32 + RenCol
    ld a, (.topY)
    ld l, a
    ld h, 0
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    ld a, (RenCol)
    or l
    ld l, a
    ld a, h
    add a, high(VBUF_PX)
    ld h, a                     ; HL = VBUF_PX[topY][RenCol]

    ; Draw rows c = topY .. botY
    ld a, (.topY)
    ld c, a                     ; C = current row y
    ld a, (.botY)
    sub c
    inc a
    ld b, a                     ; B = total rows to draw (botY - topY + 1)
    ld de, 32

.strip_loop:
    ; Top roof fascia solid check: if c < topSolidEnd -> $FF
    ld a, (.topSolidEnd)
    dec a
    cp c                        ; Carry if (topSolidEnd - 1) < c (i.e. c >= topSolidEnd)
    jr nc, .solid_row

    ; Bottom foundation solid check: if c >= botSolidStart -> $FF
    ld a, c
    push hl
    ld hl, .botSolidStart
    cp (hl)
    pop hl
    jr nc, .solid_row

    ; Textured building body!
    ld a, c
    and $03
    jr z, .p0
    dec a
    jr z, .p1
    dec a
    jr z, .p2
    ld a, (ix + 3)
    jr .pwrite
.p0:
    ld a, (ix + 0)
    jr .pwrite
.p1:
    ld a, (ix + 1)
    jr .pwrite
.p2:
    ld a, (ix + 2)
    jr .pwrite
.solid_row:
    ld a, $FF
.pwrite:
    ld (hl), a
    add hl, de
    inc c
    djnz .strip_loop

    ; Clear remaining ground rows inside botCh (botY+1 .. botCh*4+3) to $00
    ; so ZERO road/plaza pixels get tinted by the building's color!
    ld a, (.botY)
    and $03
    ld b, a
    ld a, 3
    sub b                       ; Remaining rows in botCh (0..3)
    jr z, .next_wall_col
    ld b, a
    xor a
.clr_tail:
    ld (hl), a
    add hl, de
    djnz .clr_tail

.next_wall_col:
    ld hl, RenCol
    inc (hl)
    ld a, (hl)
    cp 32
    jp c, .wall_col_loop
    ret

.tileIdx:       db 0
.topY:          db 0
.botY:          db 0
.wallAttr:      db 0
.topSolidEnd:   db 0
.botSolidStart: db 0

; Ink colors for solid tiles 4..10
WallInkTable:
    db 2                        ; 4: Red Brick Building
    db 5                        ; 5: Cyan Glass Skyscraper
    db 6                        ; 6: Yellow Commercial / Diner
    db 7                        ; 7: White Concrete Tower / Stadium
    db 3                        ; 8: Magenta Neon Arcade
    db 4                        ; 9: Green Park Trees
    db 7                        ; 10: White Highway Guardrail

; Rich 8-pixel-wide architectural textures (7 tiles x 4 bytes lit, then 7 x 4 shaded)
WallPatterns:
    ; Lit facades (sunlit E/W walls): crisp twin windows & architectural detail!
    db %11111111, %10011001, %10011001, %11111111   ; 4: Red Brick (twin windows!)
    db %11111111, %10101010, %10101010, %10101010   ; 5: Cyan Glass Skyscraper
    db %11111111, %11011011, %01100110, %11111111   ; 6: Yellow Commercial Diner
    db %11111111, %11101110, %11111111, %01110111   ; 7: White Concrete Stadium
    db %11111111, %00000000, %11111111, %10101010   ; 8: Magenta Neon Arcade!
    db %10101101, %01110110, %11011011, %01101101   ; 9: Green Park Trees
    db %11001100, %01100110, %00110011, %10011001   ; 10: Diagonal Guardrail
    ; Shaded facades (N/S walls): darker dither for crisp 3D corners!
    db %10101010, %10001000, %00000000, %01010101   ; 4 shaded
    db %01010101, %10001000, %01000100, %10001000   ; 5 shaded
    db %10101010, %01000100, %01010101, %00100010   ; 6 shaded
    db %10101010, %01000100, %10101010, %00100010   ; 7 shaded
    db %10101010, %00000000, %01010101, %00100010   ; 8 shaded
    db %01001010, %00100100, %10010010, %01001001   ; 9 shaded
    db %10001000, %01000100, %00100010, %00010001   ; 10 shaded

; -----------------------------------------------------------------------------
; BlitViewport
; Interleaved char-row blit: for each of the 16 viewport char rows (rows 1..16),
; copies 4 double-rows of pixels (8 scanlines) AND immediately copies that row's
; 32 attribute bytes -> keeps pixels & attributes locked together (zero color
; ghosting during fast driving!) and uses unrolled LDI for maximum speed!
; -----------------------------------------------------------------------------
BlitViewport:
    ld hl, VBUF_PX
    ld (.pxPtr), hl
    ld hl, VBUF_ATTR
    ld (.atSrc), hl
    ld hl, $5820                ; Screen attribute row 1
    ld (.atDst), hl
    ld a, 8                     ; Starting scanline Y = 8 (char row 1)
    ld (.curY), a
    ld b, 16                    ; 16 character rows (Y = 8..135)

.blit_ch_loop:
    push bc
    ld hl, (.pxPtr)
    ld c, 4                     ; 4 double-rows (= 8 scanlines) per char row

.blit_row_loop:
    push bc
    push hl

    ld a, (.curY)
    ld l, a
    ld h, high(ScrRowLo)
    ld e, (hl)
    inc h
    ld d, (hl)

    pop hl

    push hl
    push de
    DUP 32
        ldi
    EDUP

    pop de
    pop hl
    inc d                       ; Odd scanline Y+1 = even + $0100
    DUP 32
        ldi
    EDUP

    ld a, (.curY)
    add a, 2
    ld (.curY), a

    pop bc
    dec c
    jp nz, .blit_row_loop

    ld (.pxPtr), hl

    ; Immediately blit this char row's 32 attribute bytes!
    ld hl, (.atSrc)
    ld de, (.atDst)
    DUP 32
        ldi
    EDUP
    ld (.atSrc), hl
    ld (.atDst), de

    pop bc
    dec b
    jp nz, .blit_ch_loop
    ret

.curY:  db 0
.pxPtr: dw 0
.atSrc: dw 0
.atDst: dw 0

; -----------------------------------------------------------------------------
; RenderCarOverlay
; Crisp 1:1 resolution 3rd-Person Sports Car (Y=114..133, cols 14..17) OR
; 1st-Person Red Hood & Windshield A-pillars (Y=128..135, zero clash!).
; -----------------------------------------------------------------------------
RenderCarOverlay:
    ld a, (CamMode)
    or a
    jp nz, RenderFirstPersonOverlay

    ; === 3RD-PERSON CHASE SPORTS CAR ===
    ld a, (CarSteer)
    or a
    jr z, .car_straight
    jp m, .car_left
    ld hl, CarSpriteRight
    ld de, CarMaskRight
    jr .car_draw
.car_left:
    ld hl, CarSpriteLeft
    ld de, CarMaskLeft
    jr .car_draw
.car_straight:
    ld hl, CarSpriteCenter
    ld de, CarMaskCenter

.car_draw:
    ld (.sprPtr), hl
    ld (.mskPtr), de

    ; Position car flush with bottom of viewport (Y = 116..135 -> zero stray pixels below tires!)
    ld a, 116
    ld (.curY), a

    ld b, 20
.car_row_loop:
    push bc

    ld a, (.curY)
    ld l, a
    ld h, high(ScrRowLo)
    ld a, (hl)
    add a, 14
    ld e, a
    inc h
    ld d, (hl)

    ld hl, (.mskPtr)
    ld ix, (.sprPtr)
    ld b, 4
.car_col_loop:
    ld a, (de)
    and (hl)
    or (ix + 0)
    ld (de), a
    inc de
    inc hl
    inc ix
    djnz .car_col_loop

    ld (.mskPtr), hl
    ld (.sprPtr), ix

    ld a, (.curY)
    inc a
    ld (.curY), a
    pop bc
    djnz .car_row_loop

    ; Car attributes: adapt paper color (Black on road, Green when off-road on grass!)
    ld a, (CarOnGrass)
    or a
    ld c, $00                   ; Black paper on road/plaza
    jr z, .car_bg_ok
    ld c, $20                   ; Green paper on grass!
.car_bg_ok:
    ; Row 14: ONLY cols 15..16 (roof & rear glass) -> leaves cols 14 & 17 walls untouched!
    ld hl, $5800 + (14 * 32) + 15
    ld a, $05 : or c : ld (hl), a : inc hl
    ld (hl), a

    ; Row 15: Main red sports car body + glowing brake lights
    ld a, (CarBraking)
    or a
    ld b, $42
    jr z, .no_brk_col
    ld b, $46
.no_brk_col:
    ld hl, $5800 + (15 * 32) + 14
    ld (hl), b
    inc hl
    ld (hl), $42
    inc hl
    ld (hl), $42
    inc hl
    ld (hl), b

    ; Row 16: Tires & lower bumper (Y = 128..135 flush to bottom)
    ld hl, $5800 + (16 * 32) + 14
    ld a, $07 : or c : ld (hl), a : inc hl
    ld a, $02 : or c : ld (hl), a : inc hl
    ld (hl), a : inc hl
    ld a, $07 : or c : ld (hl), a
    ret

.sprPtr: dw 0
.mskPtr: dw 0
.curY:   db 0

; -----------------------------------------------------------------------------
; RenderFirstPersonOverlay
; Crisp 1P Car Hood on exact char row 16 (Y=128..135 -> ZERO color clash!)
; with twin bright white racing stripes + dark windshield A-pillars!
; -----------------------------------------------------------------------------
RenderFirstPersonOverlay:
    ; Windshield A-pillars along far-left col 0 & far-right col 31 (Y=8..135)
    ld a, 8
    ld (.fpY), a
    ld b, 128
.pillar_loop:
    push bc
    ld a, (.fpY)
    ld l, a
    ld h, high(ScrRowLo)
    ld e, (hl)
    inc h
    ld d, (hl)
    ld a, (de)
    or %11000000
    ld (de), a
    ld a, e
    add a, 31
    ld e, a
    ld a, (de)
    or %00000011
    ld (de), a
    ld a, (.fpY)
    inc a
    ld (.fpY), a
    pop bc
    djnz .pillar_loop

    ; Sleek Red Car Bonnet across exact char row 16 (Y = 128..135, cols 6..25)
    ld a, 128
    ld (.fpY), a
    ld c, 0
.hood_loop:
    ld a, (.fpY)
    ld l, a
    ld h, high(ScrRowLo)
    ld e, (hl)
    inc h
    ld d, (hl)

    ld a, c
    cp 2
    jr nc, .hood_body
    ; Curved front lip (cols 7..24)
    ld hl, 7
    add hl, de
    ld (hl), %00111111
    inc hl
    ld b, 16
.hlip:
    ld (hl), %11111111
    inc hl
    djnz .hlip
    ld (hl), %11111100
    jr .hood_stripes
.hood_body:
    ld hl, 6
    add hl, de
    ld (hl), %00111111
    inc hl
    ld b, 18
.hmid:
    ld (hl), %11111111
    inc hl
    djnz .hmid
    ld (hl), %11111100

.hood_stripes:
    ; Twin racing stripes at cols 14 and 17
    ld hl, 14
    add hl, de
    ld (hl), %11000011
    ld hl, 17
    add hl, de
    ld (hl), %11000011

    ld a, (.fpY)
    inc a
    ld (.fpY), a
    inc c
    ld a, c
    cp 8
    jr c, .hood_loop

    ; Color char row 16 cols 6..25 -> Bright Red ($42), racing stripes White ($47)
    ld hl, $5800 + (16 * 32) + 6
    ld b, 20
    ld a, $42
.hattr:
    ld (hl), a
    inc hl
    djnz .hattr
    ld a, $47
    ld ($5800 + (16 * 32) + 14), a
    ld ($5800 + (16 * 32) + 17), a
    ret

.fpY: db 0

; =============================================================================
; 3rd-Person Sports Car Pixel Art (32x20, crisp solid underbody masks!)
; =============================================================================
CarSpriteCenter:
    db %00000000, %00111111, %11111100, %00000000  ; 00 Roof top
    db %00000000, %01111111, %11111110, %00000000  ; 01 Roof
    db %00000000, %11001111, %11110011, %00000000  ; 02 Rear glass top
    db %00000000, %10011111, %11111001, %00000000  ; 03 Rear glass
    db %00000011, %10011111, %11111001, %11000000  ; 04 Rear pillars
    db %00001111, %11111111, %11111111, %11110000  ; 05 Rear spoiler wing!
    db %00001100, %00000000, %00000000, %00110000  ; 06 Spoiler struts
    db %00011111, %11111111, %11111111, %11111000  ; 07 Upper rear deck
    db %00111111, %11111111, %11111111, %11111100  ; 08 Wide fenders
    db %01111100, %11111111, %11111111, %00111110  ; 09 Taillight bar top
    db %01101100, %11100000, %00000111, %00110110  ; 10 Taillights + plate
    db %01111100, %11101110, %01110111, %00111110  ; 11 Taillights + plate
    db %01111111, %11100000, %00000111, %11111110  ; 12 Lower fascia
    db %01111111, %11111111, %11111111, %11111110  ; 13 Rear bumper
    db %00111111, %11111111, %11111111, %11111100  ; 14 Bumper lower edge
    db %00111110, %00000000, %00000000, %01111100  ; 15 Wide rear tires
    db %00111110, %00000000, %00000000, %01111100  ; 16 Rear tires
    db %00111110, %00000000, %00000000, %01111100  ; 17 Rear tires
    db %00111100, %00000000, %00000000, %00111100  ; 18 Tire contact
    db %00011000, %00000000, %00000000, %00011000  ; 19 Tire bottom

CarMaskCenter:
    db %11111111, %11000000, %00000011, %11111111  ; 00
    db %11111111, %10000000, %00000001, %11111111  ; 01
    db %11111111, %00000000, %00000000, %11111111  ; 02
    db %11111111, %00000000, %00000000, %11111111  ; 03
    db %11111100, %00000000, %00000000, %00111111  ; 04
    db %11110000, %00000000, %00000000, %00001111  ; 05
    db %11110000, %00000000, %00000000, %00001111  ; 06
    db %11100000, %00000000, %00000000, %00000111  ; 07
    db %11000000, %00000000, %00000000, %00000011  ; 08
    db %10000000, %00000000, %00000000, %00000001  ; 09
    db %10000000, %00000000, %00000000, %00000001  ; 10
    db %10000000, %00000000, %00000000, %00000001  ; 11
    db %10000000, %00000000, %00000000, %00000001  ; 12
    db %10000000, %00000000, %00000000, %00000001  ; 13
    db %11000000, %00000000, %00000000, %00000011  ; 14
    db %11000000, %00000000, %00000000, %00000011  ; 15 Dark shadow under car!
    db %11000000, %00000000, %00000000, %00000011  ; 16 Dark shadow under car!
    db %11000000, %00000000, %00000000, %00000011  ; 17
    db %11000000, %00000000, %00000000, %00000011  ; 18
    db %11100000, %00000000, %00000000, %00000111  ; 19

CarSpriteLeft:
    db %00000000, %11111111, %11110000, %00000000  ; 00
    db %00000001, %11111111, %11111000, %00000000  ; 01
    db %00000011, %00111111, %11001100, %00000000  ; 02
    db %00000110, %01111111, %11100110, %00000000  ; 03
    db %00001110, %01111111, %11100111, %00000000  ; 04
    db %00111111, %11111111, %11111111, %11000000  ; 05
    db %00110000, %00000000, %00000000, %11000000  ; 06
    db %01111111, %11111111, %11111111, %11100000  ; 07
    db %11111111, %11111111, %11111111, %11110000  ; 08
    db %11110011, %11111111, %11110011, %11111000  ; 09
    db %11010011, %10000000, %00110011, %01111000  ; 10
    db %11110011, %10111011, %00110011, %11111000  ; 11
    db %11111111, %10000000, %00111111, %11111000  ; 12
    db %11111111, %11111111, %11111111, %11111000  ; 13
    db %01111111, %11111111, %11111111, %11110000  ; 14
    db %01111100, %00000000, %00000001, %11110000  ; 15
    db %00111110, %00000000, %00000001, %11110000  ; 16
    db %00011111, %00000000, %00000000, %11111000  ; 17
    db %00011110, %00000000, %00000000, %11110000  ; 18
    db %00001100, %00000000, %00000000, %01100000  ; 19

CarMaskLeft:
    db %11111111, %00000000, %00001111, %11111111  ; 00
    db %11111110, %00000000, %00000111, %11111111  ; 01
    db %11111100, %00000000, %00000011, %11111111  ; 02
    db %11111000, %00000000, %00000001, %11111111  ; 03
    db %11110000, %00000000, %00000000, %11111111  ; 04
    db %11000000, %00000000, %00000000, %00111111  ; 05
    db %11000000, %00000000, %00000000, %00111111  ; 06
    db %10000000, %00000000, %00000000, %00011111  ; 07
    db %00000000, %00000000, %00000000, %00001111  ; 08
    db %00000000, %00000000, %00000000, %00000111  ; 09
    db %00000000, %00000000, %00000000, %00000111  ; 10
    db %00000000, %00000000, %00000000, %00000111  ; 11
    db %00000000, %00000000, %00000000, %00000111  ; 12
    db %00000000, %00000000, %00000000, %00000111  ; 13
    db %10000000, %00000000, %00000000, %00001111  ; 14
    db %10000000, %00000000, %00000000, %00001111  ; 15
    db %11000000, %00000000, %00000000, %00001111  ; 16
    db %11100000, %00000000, %00000000, %00000111  ; 17
    db %11100000, %00000000, %00000000, %00001111  ; 18
    db %11110000, %00000000, %00000000, %10011111  ; 19

CarSpriteRight:
    db %00000000, %00001111, %11111111, %00000000  ; 00
    db %00000000, %00011111, %11111111, %10000000  ; 01
    db %00000000, %00110011, %11111100, %11000000  ; 02
    db %00000000, %01100111, %11111110, %01100000  ; 03
    db %00000000, %11100111, %11111110, %01110000  ; 04
    db %00000011, %11111111, %11111111, %11111100  ; 05
    db %00000011, %00000000, %00000000, %00001100  ; 06
    db %00000111, %11111111, %11111111, %11111110  ; 07
    db %00001111, %11111111, %11111111, %11111111  ; 08
    db %00011111, %11001111, %11111111, %11001111  ; 09
    db %00011110, %11001100, %00000001, %11001011  ; 10
    db %00011111, %11001100, %11011101, %11001111  ; 11
    db %00011111, %11111100, %00000001, %11111111  ; 12
    db %00011111, %11111111, %11111111, %11111111  ; 13
    db %00001111, %11111111, %11111111, %11111110  ; 14
    db %00001111, %10000000, %00000000, %00111110  ; 15
    db %00001111, %10000000, %00000000, %01111100  ; 16
    db %00011111, %00000000, %00000000, %11111000  ; 17
    db %00001111, %00000000, %00000000, %01111000  ; 18
    db %00000110, %00000000, %00000000, %00110000  ; 19

CarMaskRight:
    db %11111111, %11110000, %00000000, %11111111  ; 00
    db %11111111, %11100000, %00000000, %01111111  ; 01
    db %11111111, %11000000, %00000000, %00111111  ; 02
    db %11111111, %10000000, %00000000, %00011111  ; 03
    db %11111111, %00000000, %00000000, %00001111  ; 04
    db %11111100, %00000000, %00000000, %00000011  ; 05
    db %11111100, %00000000, %00000000, %00000011  ; 06
    db %11111000, %00000000, %00000000, %00000001  ; 07
    db %11110000, %00000000, %00000000, %00000000  ; 08
    db %11100000, %00000000, %00000000, %00000000  ; 09
    db %11100000, %00000000, %00000000, %00000000  ; 10
    db %11100000, %00000000, %00000000, %00000000  ; 11
    db %11100000, %00000000, %00000000, %00000000  ; 12
    db %11100000, %00000000, %00000000, %00000000  ; 13
    db %11110000, %00000000, %00000000, %00000001  ; 14
    db %11110000, %00000000, %00000000, %00000001  ; 15
    db %11110000, %00000000, %00000000, %00000011  ; 16
    db %11100000, %00000000, %00000000, %00000111  ; 17
    db %11110000, %00000000, %00000000, %00000111  ; 18
    db %11111001, %00000000, %00000000, %00001111  ; 19
