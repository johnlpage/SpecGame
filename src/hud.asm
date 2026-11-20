; =============================================================================
; src/hud.asm — Top Status Bar, Bottom Instrument Panel, Rotating Steering
;               Wheel (1P), Telemetry Compass (3P), & Live 32x32 City Minimap
; =============================================================================

; -----------------------------------------------------------------------------
; InitHUD
; Draws static dashboard frames, labels, builds the 128-byte cached minimap
; bitmap from WorldMap ($D000), and renders initial top/bottom panels.
; -----------------------------------------------------------------------------
InitHUD:
    ; Set top bar (row 0) attributes to Bright White on Blue ($4F)
    ld hl, $5800
    ld de, $5801
    ld bc, 31
    ld (hl), ATTR_HUD_TOP
    ldir

    ; Clear bottom panel pixels (Y = 136..191, char rows 17..23)
    ld a, 136
.clr_bot:
    push af
    ld l, a
    ld h, high(ScrRowLo)
    ld e, (hl)
    inc h
    ld d, (hl)
    ex de, hl
    ld d, h
    ld e, l
    inc de
    ld bc, 31
    ld (hl), 0
    ldir
    pop af
    inc a
    cp 192
    jr c, .clr_bot

    ; Set bottom panel attributes (rows 17..23 = $5A20..$5AFF, 224 bytes)
    ld hl, $5800 + (17 * 32)
    ld de, $5800 + (17 * 32) + 1
    ld bc, 223
    ld (hl), $07                ; Black paper, White ink
    ldir

    ; Draw sleek double-line dashboard top divider on row 17 (Y = 136..143)
    ld a, 138
    call DrawHorizLine
    ld a, 140
    call DrawHorizLine
    ; Color divider row 17 Bright Cyan on Black ($45)
    ld hl, $5800 + (17 * 32)
    ld de, $5800 + (17 * 32) + 1
    ld bc, 31
    ld (hl), $45
    ldir

    ; Draw static Top HUD labels
    ld bc, $0000                ; B=col 0, C=row 0
    ld hl, StrHudTop
    call DrawString

    ; Draw static Left Dashboard labels
    ld b, 0
    ld c, 18
    ld hl, StrSpeedLabel
    call DrawString

    ld b, 0
    ld c, 20
    ld hl, StrGearLabel
    call DrawString

    ld b, 0
    ld c, 21
    ld hl, StrScoreLabel
    call DrawString

    ; Color left labels
    ld hl, $5800 + (18 * 32)
    ld b, 11
.c_l18:
    ld (hl), $47                ; Bright White
    inc hl
    djnz .c_l18

    ; Speed bar row 19: cols 0..3 Green, 4..7 Yellow, 8..10 Red!
    ld hl, $5800 + (19 * 32)
    ld (hl), $44 : inc hl
    ld (hl), $44 : inc hl
    ld (hl), $44 : inc hl
    ld (hl), $44 : inc hl
    ld (hl), $46 : inc hl
    ld (hl), $46 : inc hl
    ld (hl), $46 : inc hl
    ld (hl), $46 : inc hl
    ld (hl), $42 : inc hl
    ld (hl), $42 : inc hl
    ld (hl), $42

    ; Target checkpoint row 22 & 23 left side: Bright Yellow ($46) / Cyan ($45)
    ld hl, $5800 + (22 * 32)
    ld b, 13
.c_l22:
    ld (hl), $46
    inc hl
    djnz .c_l22
    ld hl, $5800 + (23 * 32)
    ld b, 13
.c_l23:
    ld (hl), $45
    inc hl
    djnz .c_l23

    ; Minimap header "MAP" above right radar (row 18, cols 26..30) — pure monochrome!
    ld b, 26
    ld c, 18
    ld hl, StrMapTitle
    call DrawString
    ld hl, $5800 + (18 * 32) + 25
    ld b, 6
.c_map_hdr:
    ld (hl), $07                ; Monochrome White on Black
    inc hl
    djnz .c_map_hdr

    ; Orientation hint "N=UP" below monochrome map (row 23, cols 26..29)
    ld b, 26
    ld c, 23
    ld hl, StrMapHint
    call DrawString
    ld hl, $5800 + (23 * 32) + 26
    ld b, 4
.c_map_ftr:
    ld (hl), $07
    inc hl
    djnz .c_map_ftr

    ; Pre-build 128-byte static 32x32 city map bitmap from WorldMap ($D000)
    call BuildMinimapCache

    ; Draw center panel for initial camera mode
    ld a, (CamMode)
    ld (PrevCamMode), a
    call InitCenterPanel
    ret

; DrawHorizLine: fills scanline Y=A across all 32 cols with $FF
DrawHorizLine:
    ld l, a
    ld h, high(ScrRowLo)
    ld e, (hl)
    inc h
    ld d, (hl)
    ex de, hl
    ld d, h
    ld e, l
    inc de
    ld bc, 31
    ld (hl), $FF
    ldir
    ret

; -----------------------------------------------------------------------------
; InitCenterPanel
; Clears center panel (cols 13..24, rows 18..23) and draws static frame/labels
; for either 1st-Person Cockpit (Steering Wheel) or 3rd-Person Telemetry!
; -----------------------------------------------------------------------------
InitCenterPanel:
    ; Clear pixel rows Y = 144..191 across cols 13..24
    ld a, 144
.icp_y:
    push af
    ld l, a
    ld h, high(ScrRowLo)
    ld a, (hl)
    add a, 13
    ld e, a
    inc h
    ld d, (hl)
    ex de, hl
    ld b, 12
    xor a
.icp_x:
    ld (hl), a
    inc hl
    djnz .icp_x
    pop af
    inc a
    cp 192
    jr c, .icp_y

    ; Set attributes cols 13..24, rows 18..23 to $07
    ld c, 18
.icp_ay:
    ld l, c
    ld h, 0
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    ld de, $5800 + 13
    add hl, de
    ld b, 12
.icp_ax:
    ld (hl), $07
    inc hl
    djnz .icp_ax
    inc c
    ld a, c
    cp 24
    jr c, .icp_ay

    ld a, (CamMode)
    or a
    jr nz, .init_1p_panel

    ; --- 3P Telemetry Center Panel ---
    ld b, 13
    ld c, 18
    ld hl, Str3PTitle
    call DrawString
    ld b, 13
    ld c, 21
    ld hl, StrCtrl1
    call DrawString
    ld b, 13
    ld c, 22
    ld hl, StrCtrl2
    call DrawString
    ld b, 13
    ld c, 23
    ld hl, StrCtrl3
    call DrawString

    ; Color 3P header Bright Yellow, controls Dim Cyan/White
    ld hl, $5800 + (18 * 32) + 13
    ld b, 12
.c3p_hdr:
    ld (hl), $46
    inc hl
    djnz .c3p_hdr
    ld hl, $5800 + (19 * 32) + 13
    ld b, 12
.c3p_arr:
    ld (hl), $45                ; Bright Cyan compass arrow
    inc hl
    djnz .c3p_arr
    ld hl, $5800 + (20 * 32) + 13
    ld b, 12
.c3p_surf:
    ld (hl), $44                ; Bright Green surface status
    inc hl
    djnz .c3p_surf
    ret

.init_1p_panel:
    ; --- 1P Cockpit Center Panel (Animated Steering Wheel) ---
    ld b, 14
    ld c, 18
    ld hl, Str1PTitle
    call DrawString
    ld hl, $5800 + (18 * 32) + 14
    ld b, 10
.c1p_hdr:
    ld (hl), $45
    inc hl
    djnz .c1p_hdr

    ; Color steering wheel area (rows 19..22, cols 17..20) Bright White + Red top stripe!
    ld c, 19
.sw_ay:
    ld l, c
    ld h, 0
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    ld de, $5800 + 17
    add hl, de
    ld b, 4
.sw_ax:
    ld (hl), $47                ; Bright White wheel
    inc hl
    djnz .sw_ax
    inc c
    ld a, c
    cp 23
    jr c, .sw_ay
    ; Top-center red rally marker on wheel
    ld a, $42
    ld ($5800 + (19 * 32) + 18), a
    ld ($5800 + (19 * 32) + 19), a

    ld b, 13
    ld c, 23
    ld hl, StrCtrl3
    call DrawString
    ret

; -----------------------------------------------------------------------------
; UpdateHUD
; Refreshes dynamic HUD elements every frame: speed, heading, checkpoints,
; camera indicator, speed bar, gear, score, checkpoint name/arrow, center
; panel (steering wheel or 3P telemetry), and live 32x32 open-world minimap!
; -----------------------------------------------------------------------------
UpdateHUD:
    ; If camera mode changed since last frame, re-init center panel!
    ld a, (CamMode)
    ld hl, PrevCamMode
    cp (hl)
    jr z, .same_mode
    ld (hl), a
    call InitCenterPanel
.same_mode:

    ; --- 1. Top Bar: Speed (km/h = abs(CarSpeed) * 2) at col 4, row 0 ---
    ld a, (CarSpeed)
    or a
    jp p, .spd_pos
    neg
.spd_pos:
    add a, a                    ; * 2 -> 0..208 km/h
    ld b, 4
    ld c, 0
    call DrawDec3

    ; --- 2. Top Bar: Countdown Deadline Timer (TIME:XX) at col 14, row 0 ---
    ld a, (MissionTimer)
    ld b, 14
    ld c, 0
    call DrawDec2

    ; Flash TIME:XX Bright White on Red ($57) when <= 10 seconds left!
    ld a, (MissionTimer)
    cp 11
    ld e, ATTR_HUD_TOP
    jr nc, .time_col_ok
    ld a, (FrameCounter)
    bit 1, a
    jr z, .time_col_ok
    ld e, $57                   ; Bright Red paper, White ink alert!
.time_col_ok:
    ld hl, $5800 + 9
    ld b, 7
.time_attr_loop:
    ld (hl), e
    inc hl
    djnz .time_attr_loop

    ; --- 3. Top Bar: Mission Leg (01..12) at col 22, row 0 ---
    ld a, (CurMissionIdx)
    inc a
    ld b, 22
    ld c, 0
    call DrawDec2

    ; --- 4. Top Bar: Camera Mode ("3P" or "1P") at col 29, row 0 ---
    ld a, (CamMode)
    or a
    ld a, '3'
    jr z, .cam_ch_ok
    ld a, '1'
.cam_ch_ok:
    ld b, 29
    ld c, 0
    call DrawChar

    ; --- 5. Left Dashboard: Graphical Speed Bar (row 19, cols 0..10) ---
    call DrawSpeedBar

    ; --- 6. Left Dashboard: Gear (col 5, row 20) + Compass Heading (col 10..11, row 20) ---
    ld a, (CarSpeed)
    or a
    jr z, .gear_n
    jp m, .gear_r
    cp 28
    jr c, .gear_1
    cp 56
    jr c, .gear_2
    cp 84
    jr c, .gear_3
    ld a, '4'
    jr .draw_gear
.gear_3:
    ld a, '3'
    jr .draw_gear
.gear_2:
    ld a, '2'
    jr .draw_gear
.gear_1:
    ld a, '1'
    jr .draw_gear
.gear_r:
    ld a, 'R'
    jr .draw_gear
.gear_n:
    ld a, 'N'
.draw_gear:
    ld b, 5
    ld c, 20
    call DrawChar

    ; Compass heading (N/NE/E/SE/S/SW/W/NW) at col 10..11, row 20
    ld a, (CarAngle)
    add a, 16
    rlca
    rlca
    rlca
    and $07
    add a, a
    ld e, a
    ld d, 0
    ld hl, HeadingNames
    add hl, de
    ld a, (hl)
    inc hl
    push hl
    ld b, 10
    ld c, 20
    call DrawChar
    pop hl
    ld a, (hl)
    ld b, 11
    ld c, 20
    call DrawChar

    ; --- 7. Left Dashboard: Score (col 4, row 21) ---
    ld hl, (Score)
    ld b, 4
    ld c, 21
    call DrawDec4

    ; --- 8. Left Dashboard: Active Story Objective (row 22) & Target Location (row 23) ---
    ld a, (CurMissionIdx)
    ld hl, .lastMissionDrawn
    cp (hl)
    jr z, .update_center
    ld (hl), a

    ; Draw 12-char MissionHudObj at col 0, row 22
    ld e, a
    add a, a
    add a, e                    ; * 3
    add a, a
    add a, a                    ; * 12
    ld e, a
    ld d, 0
    push de
    ld hl, MissionHudObj
    add hl, de
    ld b, 0
    ld c, 22
    ld d, 12
    call DrawFixedStr

    ; Draw 12-char MissionHudLoc at col 0, row 23
    pop de
    ld hl, MissionHudLoc
    add hl, de
    ld b, 0
    ld c, 23
    ld d, 12
    call DrawFixedStr

.update_center:
    ; --- 9. Center Panel: 1P Steering Wheel OR 3P Surface & Drive Status ---
    ld a, (CamMode)
    or a
    jr nz, .upd_1p_wheel

    ; 3P Mode row 19: Surface status (ASPHALT / OFFROAD)
    ld a, (CarOnGrass)
    or a
    ld hl, StrSurfRoad
    jr z, .surf_ok
    ld hl, StrSurfGrass
.surf_ok:
    ld b, 13
    ld c, 19
    call DrawString

    ; 3P Mode row 20: Driving status (DRIFT / BRAKE / CRUISING)
    ld a, (InputState)
    bit 4, a
    ld hl, StrStatDrift
    jr nz, .st3_draw
    ld a, (CarBraking)
    or a
    ld hl, StrStatBrake
    jr nz, .st3_draw
    ld hl, StrStatDrive
.st3_draw:
    ld b, 14
    ld c, 20
    call DrawString
    jr .update_minimap

.upd_1p_wheel:
    call DrawSteeringWheel

.update_minimap:
    ; --- 10. Right Panel: Live Monochrome 32x32 Open-World City Map ---
    call DrawMinimap
    ret

.lastMissionDrawn: db $FF

; DrawFixedStr: draws D chars from HL starting at (B=col, C=row)
DrawFixedStr:
    push bc
    push de
    push hl
    ld a, (hl)
    call DrawChar
    pop hl
    pop de
    pop bc
    inc hl
    inc b
    dec d
    jr nz, DrawFixedStr
    ret

; -----------------------------------------------------------------------------
; DrawSpeedBar
; Draws a 10-cell (80px) horizontal speed bar at row 19 (Y = 152..159, cols 0..9)
; -----------------------------------------------------------------------------
DrawSpeedBar:
    ld a, (CarSpeed)
    or a
    jp p, .sb_pos
    neg
.sb_pos:
    ; Map 0..104 -> 0..10 filled cells (divide by ~10: >> 3 capped at 10)
    srl a
    srl a
    srl a
    cp 11
    jr c, .sb_ok
    ld a, 10
.sb_ok:
    ld d, a                     ; D = filled cell count (0..10)

    ld b, 0                     ; Col 0..9
.sb_col:
    ld a, b
    cp d
    ld e, %11111110             ; Solid lit bar segment
    jr c, .sb_draw
    ld e, %00000000             ; Empty dark segment
.sb_draw:
    ; Fill scanlines Y = 154..157 (4px tall bar inside row 19)
    ld c, 154
.sb_y:
    ld l, c
    ld h, high(ScrRowLo)
    ld a, (hl)
    add a, b
    ld l, a
    ld a, (ScrRowHi + 154)      ; Note: Y=154..157 are ALL in same char cell!
    ; Safer: look up ScrRowHi[C] directly
    push hl
    ld l, c
    ld h, high(ScrRowHi)
    ld a, (hl)
    pop hl
    ld h, a
    ld (hl), e
    inc c
    ld a, c
    cp 158
    jr c, .sb_y

    inc b
    ld a, b
    cp 10
    jr c, .sb_col
    ret

; -----------------------------------------------------------------------------
; DrawSteeringWheel
; Draws 32x24 animated steering wheel in 1P cockpit mode (cols 17..20, Y=152..175)
; based on CarSteer (-1 = Left, 0 = Straight, +1 = Right).
; -----------------------------------------------------------------------------
DrawSteeringWheel:
    ld a, (CarSteer)
    or a
    jr z, .sw_center
    jp m, .sw_left
    ld hl, WheelRight
    jr .sw_go
.sw_left:
    ld hl, WheelLeft
    jr .sw_go
.sw_center:
    ld hl, WheelCenter
.sw_go:
    ld (.wPtr), hl
    ld a, 152                   ; Start scanline Y = 152 (char row 19)
    ld (.wY), a
    ld b, 24                    ; 24 scanlines tall
.sw_row:
    push bc
    ld a, (.wY)
    ld l, a
    ld h, high(ScrRowLo)
    ld a, (hl)
    add a, 17                   ; Cols 17..20
    ld e, a
    inc h
    ld d, (hl)
    ld hl, (.wPtr)
    ld bc, 4
    ldir
    ld (.wPtr), hl
    ld a, (.wY)
    inc a
    ld (.wY), a
    pop bc
    djnz .sw_row
    ret
.wPtr: dw 0
.wY:   db 0

; -----------------------------------------------------------------------------
; BuildMinimapCache
; Converts 32x32 WorldMap ($D000) into a 128-byte (4 bytes x 32 rows) 1-bit
; bitmap where 1 = solid building and 0 = drivable road/park/plaza!
; -----------------------------------------------------------------------------
BuildMinimapCache:
    ld hl, WorldMap             ; $D000
    ld de, MinimapCache         ; 128-byte buffer
    ld c, 32                    ; 32 rows
.bm_row:
    ld b, 4                     ; 4 bytes (32 tiles) per row
.bm_byte:
    push bc
    ld b, 8                     ; 8 tiles -> 8 bits (MSB first)
    ld c, 0
.bm_bit:
    sla c
    ld a, (hl)
    inc hl
    cp TILE_SOLID_MIN
    jr c, .bm_open
    set 0, c
.bm_open:
    djnz .bm_bit
    ld a, c
    ld (de), a
    inc de
    pop bc
    djnz .bm_byte
    dec c
    jr nz, .bm_row
    ret

; -----------------------------------------------------------------------------
; DrawMinimap
; Pure MONOCHROME ($07 White on Black) 32x32 open-world city map in
; cols 26..29, Y = 152..183 (rows 19..22):
;   - Static white pixels  = city buildings (black = open roads)
;   - Steady 2x2 white dot = player car
;   - Pulsing 3x3 '+' dot  = active mission target
; -----------------------------------------------------------------------------
DrawMinimap:
    ; Pure monochrome attribute ($07 White on Black) across entire 4x4 map!
    ld c, 19
.mm_ay:
    ld l, c
    ld h, 0
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    ld de, $5800 + 26
    add hl, de
    ld a, $07                   ; Monochrome White on Black!
    ld (hl), a : inc hl
    ld (hl), a : inc hl
    ld (hl), a : inc hl
    ld (hl), a
    inc c
    ld a, c
    cp 23
    jr c, .mm_ay

    ; Blit 32 rows x 4 bytes from MinimapCache -> screen Y = 152..183, cols 26..29
    ld hl, MinimapCache
    ld a, 152
    ld (.mY), a
    ld b, 32
.mm_row:
    push bc
    push hl
    ld a, (.mY)
    ld l, a
    ld h, high(ScrRowLo)
    ld a, (hl)
    add a, 26
    ld e, a
    inc h
    ld d, (hl)
    pop hl
    ldi
    ldi
    ldi
    ldi
    ld a, (.mY)
    inc a
    ld (.mY), a
    pop bc
    djnz .mm_row

    ; Plot pulsing target dot (3x3 '+' crosshair, smooth ~3 Hz pulse via 50 Hz SYS_FRAMES!)
    ld a, (SYS_FRAMES)
    bit 4, a
    jr nz, .mm_plot_car
    ld a, (CurCheckX)
    ld b, a
    ld a, (CurCheckY)
    ld c, a
    call PlotMinimapCross

.mm_plot_car:
    ; Plot steady player car dot (2x2 solid pixel dot)
    ld a, (CarX + 1)
    ld b, a
    ld a, (CarY + 1)
    ld c, a
    call PlotMinimapDot
    ret
.mY: db 0

; PlotMinimapCross: plots a crisp 3x3 '+' target dot centered at (B=0..31, C=0..31)
PlotMinimapCross:
    call PlotMinimapOne         ; Center (x, y)
    ; Left (x-1, y)
    ld a, b
    or a
    jr z, .c_right
    dec b
    call PlotMinimapOne
    inc b
.c_right:
    inc b
    ld a, b
    cp 32
    jr nc, .c_up
    call PlotMinimapOne
.c_up:
    dec b
    ld a, c
    or a
    jr z, .c_down
    dec c
    call PlotMinimapOne
    inc c
.c_down:
    inc c
    ld a, c
    cp 32
    ret nc
    call PlotMinimapOne
    dec c
    ret

; PlotMinimapDot: sets a 2x2 pixel block at minimap (B=0..31, C=0..31)
PlotMinimapDot:
    call PlotMinimapOne
    inc b
    ld a, b
    cp 32
    jr nc, .p_next
    call PlotMinimapOne
.p_next:
    dec b
    inc c
    ld a, c
    cp 32
    ret nc
    call PlotMinimapOne
    inc b
    ld a, b
    cp 32
    ret nc
PlotMinimapOne:
    ; Screen Y = 152 + C, Screen byte col = 26 + (B >> 3), bit = 7 - (B & 7)
    ld a, c
    add a, 152
    ld l, a
    ld h, high(ScrRowLo)
    ld e, (hl)
    inc h
    ld d, (hl)
    ld a, b
    srl a
    srl a
    srl a
    add a, 26
    add a, e
    ld e, a                     ; DE = screen byte addr
    ld a, b
    and $07
    ld hl, BitMaskTable
    add a, l
    ld l, a
    jr nc, .bm_nc
    inc h
.bm_nc:
    ld a, (de)
    or (hl)
    ld (de), a
    ret

; -----------------------------------------------------------------------------
; DrawStoryOverlay
; When GameState != STATE_DRIVING, draws a crisp framed Radio Dispatch box
; over the center of the 3D viewport (cols 3..28, rows 3..11) showing the
; active storyline briefing, deadline failure, or campaign victory!
; -----------------------------------------------------------------------------
DrawStoryOverlay:
    ld a, (GameState)
    cp STATE_DRIVING
    ret z

    ; 1. Clear box interior pixel RAM (Y = 24..95 = char rows 3..11, cols 3..28)
    ld a, 24
.ov_clr_y:
    push af
    ld l, a
    ld h, high(ScrRowLo)
    ld a, (hl)
    add a, 3
    ld e, a
    inc h
    ld d, (hl)
    ex de, hl
    ld b, 26                    ; 26 columns (cols 3..28)
    xor a
.ov_clr_x:
    ld (hl), a
    inc hl
    djnz .ov_clr_x
    pop af
    inc a
    cp 96
    jr c, .ov_clr_y

    ; 2. Draw crisp double-line border around box (top Y=26, bot Y=93, left/right walls)
    ld a, 26
    call .draw_box_hline
    ld a, 93
    call .draw_box_hline

    ; Left & right vertical box walls (Y = 26..93, col 3 left bit, col 28 right bit)
    ld a, 26
.ov_wall_y:
    push af
    ld l, a
    ld h, high(ScrRowLo)
    ld a, (hl)
    add a, 3
    ld e, a
    inc h
    ld d, (hl)
    ld a, (de)
    or %11000000
    ld (de), a
    ld a, e
    add a, 25                   ; col 28
    ld e, a
    ld a, (de)
    or %00000011
    ld (de), a
    pop af
    inc a
    cp 94
    jr c, .ov_wall_y

    ; 3. Set box attributes (rows 3..11, cols 3..28) -> clean Black paper + Bright Cyan border
    ld c, 3
.ov_attr_y:
    ld a, $47                   ; Default Bright White on Black
    cp 0                        ; (overridden per row below)
    ld a, c
    cp 3
    jr z, .ov_border_col
    cp 11
    jr z, .ov_border_col
    ld a, $47
    jr .ov_fill_row
.ov_border_col:
    ld a, $45                   ; Bright Cyan border
.ov_fill_row:
    call .set_box_row_attr
    inc c
    ld a, c
    cp 12
    jr c, .ov_attr_y

    ; 4. Dispatch content based on GameState
    ld a, (GameState)
    cp STATE_BRIEFING
    jr z, .draw_briefing
    cp STATE_FAILED
    jp z, .draw_failed
    jp .draw_victory

.draw_briefing:
    ; Row colors: Row 4 Yellow (chapter), Row 5 White (obj), Row 6 Cyan (loc),
    ; Row 8 Green (story), Row 10 Yellow (deadline + prompt)
    ld c, 4 : ld a, $46 : call .set_box_row_attr
    ld c, 5 : ld a, $47 : call .set_box_row_attr
    ld c, 6 : ld a, $45 : call .set_box_row_attr
    ld c, 8 : ld a, $44 : call .set_box_row_attr
    ld c, 10 : ld a, $46 : call .set_box_row_attr

    ; Pointer to MissionBriefing[CurMissionIdx] = MissionBriefing + idx * 96
    ; idx * 96 = (idx * 3) * 32
    ld a, (CurMissionIdx)
    ld e, a
    add a, a
    add a, e                    ; * 3 (0..33)
    ld l, a
    ld h, 0
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl                  ; * 32 -> idx * 96!
    ld de, MissionBriefing
    add hl, de

    ; Line 0: Chapter header (24 chars at col 4, row 4)
    push hl
    ld b, 4 : ld c, 4 : ld d, 24 : call DrawFixedStr
    pop hl : ld de, 24 : add hl, de

    ; Line 1: Objective (COLLECT / DELIVER at col 4, row 5)
    push hl
    ld b, 4 : ld c, 5 : ld d, 24 : call DrawFixedStr
    pop hl : ld de, 24 : add hl, de

    ; Line 2: Location (FROM / TO at col 4, row 6)
    push hl
    ld b, 4 : ld c, 6 : ld d, 24 : call DrawFixedStr
    pop hl : ld de, 24 : add hl, de

    ; Line 3: Story radio line (at col 4, row 8)
    ld b, 4 : ld c, 8 : ld d, 24 : call DrawFixedStr

    ; Line 4: Deadline + prompt (at col 4, row 10)
    ld b, 4 : ld c, 10 : ld hl, StrBriefPrompt : call DrawString
    ld a, (MissionDeadline)
    ld b, 13 : ld c, 10 : call DrawDec2
    ret

.draw_failed:
    ld c, 4 : ld a, $42 : call .set_box_row_attr    ; Bright Red alert!
    ld c, 6 : ld a, $47 : call .set_box_row_attr
    ld c, 7 : ld a, $46 : call .set_box_row_attr
    ld c, 10 : ld a, $45 : call .set_box_row_attr
    ld b, 4 : ld c, 4  : ld hl, StrFail1 : call DrawString
    ld b, 4 : ld c, 6  : ld hl, StrFail2 : call DrawString
    ld b, 4 : ld c, 7  : ld hl, StrFail3 : call DrawString
    ld b, 4 : ld c, 10 : ld hl, StrFail4 : call DrawString
    ret

.draw_victory:
    ld c, 4 : ld a, $46 : call .set_box_row_attr    ; Bright Yellow!
    ld c, 6 : ld a, $44 : call .set_box_row_attr    ; Bright Green!
    ld c, 7 : ld a, $45 : call .set_box_row_attr    ; Bright Cyan!
    ld c, 8 : ld a, $47 : call .set_box_row_attr    ; Bright White!
    ld c, 10 : ld a, $46 : call .set_box_row_attr
    ld b, 4 : ld c, 4  : ld hl, StrWin1 : call DrawString
    ld b, 4 : ld c, 6  : ld hl, StrWin2 : call DrawString
    ld b, 4 : ld c, 7  : ld hl, StrWin3 : call DrawString
    ld b, 4 : ld c, 8  : ld hl, StrWin4 : call DrawString
    ld hl, (Score)
    ld b, 17 : ld c, 8 : call DrawDec4
    ld b, 4 : ld c, 10 : ld hl, StrWin5 : call DrawString
    ret

; Helper: draw 26-col horizontal line at scanline A (cols 3..28)
.draw_box_hline:
    ld l, a
    ld h, high(ScrRowLo)
    ld a, (hl)
    add a, 3
    ld e, a
    inc h
    ld d, (hl)
    ex de, hl
    ld b, 26
    ld a, $FF
.dbh_loop:
    ld (hl), a
    inc hl
    djnz .dbh_loop
    ret

; Helper: set attribute A on row C across cols 3..28
.set_box_row_attr:
    push bc
    ld e, a
    ld l, c
    ld h, 0
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    ld bc, $5800 + 3
    add hl, bc
    ld b, 26
.sbra_loop:
    ld (hl), e
    inc hl
    djnz .sbra_loop
    pop bc
    ret

BitMaskTable:
    db $80, $40, $20, $10, $08, $04, $02, $01

; -----------------------------------------------------------------------------
; ROM Font Text Drawing Utilities (Uses ZX Spectrum 48K ROM Font at $3D00!)
; -----------------------------------------------------------------------------

; DrawString: draws null-terminated ASCII string at HL starting at (B=col, C=row)
DrawString:
    ld a, (hl)
    or a
    ret z
    push hl
    push bc
    call DrawChar
    pop bc
    pop hl
    inc hl
    inc b
    jr DrawString

; DrawChar: draws ASCII char A at character cell (B=col 0..31, C=row 0..23)
DrawChar:
    sub 32
    ld l, a
    ld h, 0
    add hl, hl
    add hl, hl
    add hl, hl
    ld de, $3D00                ; ZX Spectrum 48K ROM character bitmap table!
    add hl, de                  ; HL = 8-byte glyph in ROM

    ; Screen top scanline Y = C * 8
    ld a, c
    add a, a
    add a, a
    add a, a
    push hl
    ld l, a
    ld h, high(ScrRowLo)
    ld a, (hl)
    add a, b
    ld e, a
    inc h
    ld d, (hl)                  ; DE = top scanline of cell (B, C)
    pop hl

    ; Copy 8 scanlines using INC D!
    ld b, 8
.dc_loop:
    ld a, (hl)
    ld (de), a
    inc hl
    inc d
    djnz .dc_loop
    ret

; DrawDec2: draws unsigned A (0..99) as 2 digits at (B=col, C=row)
DrawDec2:
    ld d, '0'
.d2_tens:
    cp 10
    jr c, .d2_done
    sub 10
    inc d
    jr .d2_tens
.d2_done:
    add a, '0'
    push af
    push bc
    ld a, d
    call DrawChar
    pop bc
    inc b
    pop af
    jp DrawChar

; DrawDec3: draws unsigned A (0..255) as 3 digits at (B=col, C=row)
DrawDec3:
    ld d, '0'
.d3_hund:
    cp 100
    jr c, .d3_hdone
    sub 100
    inc d
    jr .d3_hund
.d3_hdone:
    push af
    push bc
    ld a, d
    call DrawChar
    pop bc
    inc b
    pop af
    jp DrawDec2

; DrawDec4: draws unsigned HL (0..9999) as 4 digits at (B=col, C=row)
DrawDec4:
    ld de, 1000
    call .d4_digit
    ld de, 100
    call .d4_digit
    ld de, 10
    call .d4_digit
    ld a, l
    add a, '0'
    jp DrawChar
.d4_digit:
    ld a, '0'
.d4_sub:
    or a
    sbc hl, de
    jr c, .d4_undo
    inc a
    jr .d4_sub
.d4_undo:
    add hl, de
    push hl
    push bc
    call DrawChar
    pop bc
    pop hl
    inc b
    ret

; =============================================================================
; HUD Strings & Steering Wheel Pixel Art
; =============================================================================
StrHudTop:     db "SPD:000  TIME:30  LEG:01 CAM:3P ", 0
StrSpeedLabel: db "SPEED / RPM", 0
StrGearLabel:  db "GEAR:N  H:N ", 0
StrScoreLabel: db "PTS:0000", 0
StrMapTitle:   db "MAP ", 0
StrMapHint:    db "N=UP", 0
Str3PTitle:    db "CHASE CAM 3P", 0
Str1PTitle:    db "1P COCKPIT", 0
StrCtrl1:      db "WASD/ARW:DRV", 0
StrCtrl2:      db "SPC:DRIFT   ", 0
StrCtrl3:      db "C:VIEW M:SFX", 0
StrSurfRoad:   db "SURF:ASPHALT", 0
StrSurfGrass:  db "SURF:OFFROAD", 0
StrStatDrive:  db "  CRUISING", 0
StrStatBrake:  db "  BRAKING!", 0
StrStatDrift:  db " *DRIFT!* ", 0

; Radio Dispatch Overlay strings (24 chars max, cols 4..27)
StrBriefPrompt: db "DEADLINE:00s [GAS/SPC]GO", 0
StrFail1:       db "*** DEADLINE MISSED! ***", 0
StrFail2:       db "TIME RAN OUT ON THIS RUN", 0
StrFail3:       db "BACK TO LAST CHECKPOINT!", 0
StrFail4:       db "PRESS [GAS/SPC] TO RETRY", 0
StrWin1:        db "*** SECTOR 48 FREE! *** ", 0
StrWin2:        db "GRID SYNDICATE DEFEATED!", 0
StrWin3:        db "ALL 6 CHAPTERS CLEARED! ", 0
StrWin4:        db "FINAL SCORE: 0000       ", 0
StrWin5:        db "PRESS [GAS/SPC] NEW GAME", 0

HeadingNames:
    db "E ", "SE", "S ", "SW", "W ", "NW", "N ", "NE"

; 128-byte pre-rendered 32x32 open-world minimap cache
MinimapCache:
    ds 128, 0

; --- 1P Steering Wheel Bitmaps (32x24 pixels = 4 bytes x 24 rows) ---
WheelCenter:
    db %00000000, %11111111, %11111111, %00000000  ; 00 Top rim + rally stripe
    db %00000011, %11111111, %11111111, %11000000  ; 01
    db %00001111, %11000000, %00000011, %11110000  ; 02
    db %00011110, %00000000, %00000000, %01111000  ; 03
    db %00111100, %00000000, %00000000, %00111100  ; 04
    db %01111000, %00000000, %00000000, %00011110  ; 05
    db %01110000, %00000000, %00000000, %00001110  ; 06
    db %11110000, %00000000, %00000000, %00001111  ; 07
    db %11100000, %00001111, %11110000, %00000111  ; 08 Hub top
    db %11111111, %11111111, %11111111, %11111111  ; 09 Horizontal spokes!
    db %11111111, %11111001, %10011111, %11111111  ; 10 Center hub
    db %11111111, %11111111, %11111111, %11111111  ; 11 Spokes bottom
    db %11100000, %00001111, %11110000, %00000111  ; 12
    db %11100000, %00000111, %11100000, %00000111  ; 13 Center spoke
    db %11110000, %00000111, %11100000, %00001111  ; 14
    db %01110000, %00000111, %11100000, %00001110  ; 15
    db %01111000, %00000111, %11100000, %00011110  ; 16
    db %00111100, %00000111, %11100000, %00111100  ; 17
    db %00011110, %00000111, %11100000, %01111000  ; 18
    db %00001111, %11000111, %11100011, %11110000  ; 19
    db %00000011, %11111111, %11111111, %11000000  ; 20
    db %00000000, %11111111, %11111111, %00000000  ; 21
    db %00000000, %00011111, %11111000, %00000000  ; 22
    db %00000000, %00000000, %00000000, %00000000  ; 23

WheelLeft:
    db %00000000, %11111111, %11111111, %00000000  ; 00
    db %00000011, %11111111, %11111111, %11000000  ; 01
    db %00001111, %11000000, %00000011, %11110000  ; 02
    db %00011110, %00000000, %00000001, %11111000  ; 03 Right spoke high
    db %00111100, %00000000, %00000111, %11111100  ; 04
    db %01111000, %00000000, %00111110, %00011110  ; 05
    db %01110000, %00000000, %11111000, %00001110  ; 06
    db %11110000, %00000011, %11100000, %00001111  ; 07
    db %11100000, %00001111, %11110000, %00000111  ; 08 Hub
    db %11100000, %00011111, %11111000, %00000111  ; 09
    db %11100000, %00111100, %10011100, %00000111  ; 10 Center hub
    db %11100000, %01111111, %11111100, %00000111  ; 11
    db %11100001, %11110111, %11110000, %00000111  ; 12 Left spoke low + bottom right
    db %11100111, %11000011, %11100000, %00000111  ; 13
    db %11111110, %00000001, %11110000, %00001111  ; 14
    db %01111000, %00000000, %11111000, %00001110  ; 15
    db %01111000, %00000000, %01111100, %00011110  ; 16
    db %00111100, %00000000, %00111110, %00111100  ; 17
    db %00011110, %00000000, %00011111, %01111000  ; 18
    db %00001111, %11000000, %00001111, %11110000  ; 19
    db %00000011, %11111111, %11111111, %11000000  ; 20
    db %00000000, %11111111, %11111111, %00000000  ; 21
    db %00000000, %00011111, %11111000, %00000000  ; 22
    db %00000000, %00000000, %00000000, %00000000  ; 23

WheelRight:
    db %00000000, %11111111, %11111111, %00000000  ; 00
    db %00000011, %11111111, %11111111, %11000000  ; 01
    db %00001111, %11000000, %00000011, %11110000  ; 02
    db %00011111, %10000000, %00000000, %01111000  ; 03 Left spoke high
    db %00111111, %11100000, %00000000, %00111100  ; 04
    db %01111000, %01111100, %00000000, %00011110  ; 05
    db %01110000, %00011111, %00000000, %00001110  ; 06
    db %11110000, %00000111, %11000000, %00001111  ; 07
    db %11100000, %00001111, %11110000, %00000111  ; 08 Hub
    db %11100000, %00011111, %11111000, %00000111  ; 09
    db %11100000, %00111001, %00111100, %00000111  ; 10 Center hub
    db %11100000, %00111111, %11111110, %00000111  ; 11
    db %11100000, %00001111, %11101111, %10000111  ; 12 Right spoke low + bottom left
    db %11100000, %00000111, %11000011, %11100111  ; 13
    db %11110000, %00001111, %10000000, %01111111  ; 14
    db %01110000, %00011111, %00000000, %00011110  ; 15
    db %01111000, %00111110, %00000000, %00011110  ; 16
    db %00111100, %01111100, %00000000, %00111100  ; 17
    db %00011110, %11111000, %00000000, %01111000  ; 18
    db %00001111, %11110000, %00000011, %11110000  ; 19
    db %00000011, %11111111, %11111111, %11000000  ; 20
    db %00000000, %11111111, %11111111, %00000000  ; 21
    db %00000000, %00011111, %11111000, %00000000  ; 22
    db %00000000, %00000000, %00000000, %00000000  ; 23
