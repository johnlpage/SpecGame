; =============================================================================
; src/splash.asm — AUTO-GENERATED GTA '82 (Grand Theft Auto 0) Splash Screen
; =============================================================================

ShowSplashScreen:
    call InitScreen

    ; --- 1. Draw iconic 1982 Sinclair ZX Spectrum rainbow stripes (top-right) ---
    ; Fill rows 0..1 cols 26..31 with diagonal stripe pattern
    ld a, 0
.sp_rb_y:
    push af
    ld l, a
    ld h, high(ScrRowLo)
    ld a, (hl)
    add a, 24
    ld e, a
    inc h
    ld d, (hl)
    ex de, hl
    ld b, 8
.sp_rb_x:
    ld (hl), $FF
    inc hl
    djnz .sp_rb_x
    pop af
    inc a
    cp 6
    jr c, .sp_rb_y
    ; Color Sinclair 4-stripe rainbow: Red, Yellow, Green, Cyan!
    ld hl, $5800 + 24
    ld (hl), $42 : inc hl : ld (hl), $42 : inc hl
    ld (hl), $46 : inc hl : ld (hl), $46 : inc hl
    ld (hl), $44 : inc hl : ld (hl), $44 : inc hl
    ld (hl), $45 : inc hl : ld (hl), $45

    ; Top-left cassette label
    ld b, 1 : ld c, 0 : ld hl, StrSpTop : call DrawString
    ld hl, $5800 + 1 : ld b, 22 : ld a, $07
.sp_ta: ld (hl), a : inc hl : djnz .sp_ta

    ; --- 2. Blit giant 256x40 'GTA '82' 3D logo at Y = 16..55 (rows 2..6) ---
    ld hl, SplashLogoBmp
    ld a, 16
    ld b, 40
    call BlitSplashStrip

    ; Fiery Vice-82 gradient on 'GTA' (cols 0..16) & Cyan/White on ''82' (cols 17..31)
    ; Row 2: Yellow GTA / White '82
    ld hl, $5800 + (2 * 32) : ld b, 17 : ld a, $46 : call FillAttrRun
    ld b, 15 : ld a, $47 : call FillAttrRun
    ; Row 3: Yellow GTA / Cyan '82
    ld hl, $5800 + (3 * 32) : ld b, 17 : ld a, $46 : call FillAttrRun
    ld b, 15 : ld a, $45 : call FillAttrRun
    ; Row 4: Red GTA / Cyan '82
    ld hl, $5800 + (4 * 32) : ld b, 17 : ld a, $42 : call FillAttrRun
    ld b, 15 : ld a, $45 : call FillAttrRun
    ; Row 5: Red GTA / Blue-Cyan '82
    ld hl, $5800 + (5 * 32) : ld b, 17 : ld a, $42 : call FillAttrRun
    ld b, 15 : ld a, $05 : call FillAttrRun
    ; Row 6: Magenta GTA / Cyan '82
    ld hl, $5800 + (6 * 32) : ld b, 17 : ld a, $43 : call FillAttrRun
    ld b, 15 : ld a, $45 : call FillAttrRun

    ; --- 3. Subtitle: GRAND THEFT AUTO 0 (Row 8) ---
    ld b, 7 : ld c, 8 : ld hl, StrSpSub : call DrawString
    ld hl, $5800 + (8 * 32) : ld b, 32 : ld a, $47 : call FillAttrRun

    ; --- 4. Blit 256x32 Night Skyline + Speeding GT Car at Y = 80..111 (rows 10..13) ---
    ld hl, SplashCarBmp
    ld a, 80
    ld b, 32
    call BlitSplashStrip
    ; Color skyline Cyan/Blue, speeding GT Car Bright Red ($42) in center!
    ld hl, $5800 + (10 * 32) : ld b, 32 : ld a, $05 : call FillAttrRun
    ld hl, $5800 + (11 * 32) : ld b, 32 : ld a, $05 : call FillAttrRun
    ld hl, $5800 + (12 * 32) : ld b, 12 : ld a, $45 : call FillAttrRun
    ld b, 8 : ld a, $42 : call FillAttrRun
    ld b, 12 : ld a, $05 : call FillAttrRun
    ld hl, $5800 + (13 * 32) : ld b, 12 : ld a, $07 : call FillAttrRun
    ld b, 8 : ld a, $42 : call FillAttrRun
    ld b, 12 : ld a, $07 : call FillAttrRun

    ; --- 5. Crime-Spree Tagline, Controls & 1982 Budget Cassette Footer ---
    ld b, 2 : ld c, 15 : ld hl, StrSpTag : call DrawString
    ld hl, $5800 + (15 * 32) : ld b, 32 : ld a, $46 : call FillAttrRun

    ld b, 1 : ld c, 17 : ld hl, StrSpCtl1 : call DrawString
    ld hl, $5800 + (17 * 32) : ld b, 32 : ld a, $07 : call FillAttrRun
    ld b, 2 : ld c, 18 : ld hl, StrSpCtl2 : call DrawString
    ld hl, $5800 + (18 * 32) : ld b, 32 : ld a, $45 : call FillAttrRun

    ld b, 3 : ld c, 20 : ld hl, StrSpPress : call DrawString

    ld b, 2 : ld c, 23 : ld hl, StrSpCopy : call DrawString
    ld hl, $5800 + (23 * 32) : ld b, 32 : ld a, $05 : call FillAttrRun

    ; Brief synth jingle on startup!
    ld b, 18 : ld c, 64 : call PlayTone
    ld b, 18 : ld c, 48 : call PlayTone
    ld b, 24 : ld c, 36 : call PlayTone

    ; Wait for any held key to release first
.sp_rel:
    halt
    call CheckAnyKey
    jr nz, .sp_rel

    ; Pulse 'PRESS ANY KEY TO START' until player presses any key!
.sp_wait:
    halt
    ld a, (SYS_FRAMES)
    bit 4, a
    ld a, $46
    jr z, .sp_col
    ld a, $47
.sp_col:
    ld hl, $5800 + (20 * 32)
    ld b, 32
    call FillAttrRun
    call CheckAnyKey
    jr z, .sp_wait

    ; Engine ignition beep!
    ld b, 22 : ld c, 42 : call PlayTone
    ld b, 26 : ld c, 28 : call PlayTone
    ret

; BlitSplashStrip: copies B scanlines (32 bytes each) from HL to screen Y = A
BlitSplashStrip:
    ld (.sy), a
.bss_loop:
    push bc
    push hl
    ld a, (.sy)
    ld l, a
    ld h, high(ScrRowLo)
    ld e, (hl)
    inc h
    ld d, (hl)
    pop hl
    ld bc, 32
    ldir
    ld a, (.sy)
    inc a
    ld (.sy), a
    pop bc
    djnz .bss_loop
    ret
.sy: db 0

; FillAttrRun: fills B bytes at HL with A, leaves HL pointing after run
FillAttrRun:
    ld (hl), a
    inc hl
    djnz FillAttrRun
    ret

; Splash Strings (Note: $60 in ZX Spectrum 48K ROM font is the £ symbol!)
StrSpTop:   db "ZX SPECTRUM 48K EDITION", 0
StrSpSub:   db "GRAND THEFT AUTO 0", 0
StrSpTag:   db "6 CHAPTERS - 12 TIMED JOBS!", 0
StrSpCtl1:  db "WASD/QZOP/ARW:DRIVE  SPC:DRIFT", 0
StrSpCtl2:  db "C:1P/3P VIEW   M:SOUND ON/OFF", 0
StrSpPress: db ">> PRESS ANY KEY TO PLAY <<", 0
StrSpCopy:  db "(C) 1982 SPECGAME  ONLY ", $60, "1.99!", 0

; 256x40 3D Blocky 'GTA '82' Logo Bitmap (1280 bytes)
SplashLogoBmp:
    db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    db $00, $00, $07, $FF, $FF, $FC, $01, $FF, $FF, $FF, $FF, $C0, $00, $FF, $FE, $00
    db $00, $00, $00, $FF, $C0, $1F, $FF, $FF, $F0, $00, $3F, $FF, $FF, $E0, $00, $00
    db $00, $00, $07, $FF, $FF, $FC, $01, $FF, $FF, $FF, $FF, $C0, $00, $FF, $FE, $00
    db $00, $00, $00, $FF, $C0, $1F, $FF, $FF, $F0, $00, $3F, $FF, $FF, $E0, $00, $00
    db $00, $00, $07, $FF, $FF, $FC, $01, $FF, $FF, $FF, $FF, $C0, $00, $FF, $FE, $00
    db $00, $00, $00, $FF, $C0, $1F, $FF, $FF, $F0, $00, $3F, $FF, $FF, $E0, $00, $00
    db $00, $00, $07, $FF, $FF, $FD, $01, $FF, $FF, $FF, $FF, $D0, $00, $FF, $FE, $40
    db $00, $00, $00, $FF, $D0, $1F, $FF, $FF, $F4, $00, $3F, $FF, $FF, $E4, $00, $00
    db $00, $00, $07, $FF, $FF, $FC, $81, $FF, $FF, $FF, $FF, $C8, $00, $FF, $FE, $80
    db $00, $00, $00, $FF, $C8, $1F, $FF, $FF, $F2, $00, $3F, $FF, $FF, $E8, $00, $00
    db $00, $00, $FF, $C0, $00, $7F, $E1, $FF, $FF, $FF, $FF, $D0, $1F, $F8, $3F, $F0
    db $00, $00, $00, $FF, $D3, $FF, $00, $01, $FF, $87, $FE, $00, $03, $FF, $00, $00
    db $00, $00, $FF, $CA, $AA, $FF, $E1, $FF, $FF, $FF, $FF, $C8, $1F, $FA, $BF, $F0
    db $00, $00, $00, $FF, $CB, $FF, $2A, $AB, $FF, $87, $FE, $AA, $AB, $FF, $00, $00
    db $00, $00, $FF, $D5, $55, $7F, $E1, $FF, $FF, $FF, $FF, $D0, $1F, $F9, $7F, $F0
    db $00, $00, $00, $FF, $D3, $FF, $55, $55, $FF, $87, $FE, $55, $57, $FF, $00, $00
    db $00, $00, $FF, $C8, $00, $7F, $E9, $FF, $FF, $FF, $FF, $C8, $1F, $FA, $3F, $F2
    db $00, $00, $00, $FF, $CB, $FF, $20, $01, $FF, $A7, $FE, $80, $03, $FF, $20, $00
    db $00, $00, $FF, $D0, $00, $7F, $E5, $FF, $FF, $FF, $FF, $D0, $1F, $F9, $3F, $F4
    db $00, $00, $00, $FF, $D3, $FF, $40, $01, $FF, $97, $FE, $40, $03, $FF, $40, $00
    db $00, $00, $FF, $C8, $00, $00, $08, $00, $7F, $FF, $00, $0B, $FF, $02, $01, $FF
    db $80, $00, $1F, $F8, $0B, $FF, $20, $01, $FF, $A0, $00, $80, $7F, $E0, $20, $00
    db $00, $00, $FF, $D0, $00, $05, $54, $15, $7F, $FF, $55, $53, $FF, $55, $05, $FF
    db $80, $00, $1F, $F9, $53, $FF, $40, $01, $FF, $90, $55, $40, $7F, $E5, $40, $00
    db $00, $00, $FF, $C8, $00, $0A, $A8, $2A, $FF, $FF, $2A, $AB, $FF, $2A, $03, $FF
    db $80, $00, $1F, $FA, $AB, $FF, $20, $01, $FF, $A0, $AA, $80, $7F, $EA, $A0, $00
    db $00, $00, $FF, $D0, $00, $00, $00, $00, $7F, $FF, $40, $03, $FF, $40, $01, $FF
    db $90, $00, $1F, $F9, $03, $FF, $40, $01, $FF, $90, $00, $00, $7F, $E4, $00, $00
    db $00, $00, $FF, $C8, $00, $00, $00, $00, $7F, $FF, $20, $03, $FF, $20, $01, $FF
    db $A0, $00, $1F, $FA, $03, $FF, $20, $01, $FF, $A0, $00, $00, $7F, $E8, $00, $00
    db $00, $00, $FF, $D1, $FF, $FC, $00, $00, $7F, $FF, $40, $03, $FF, $FF, $FF, $FF
    db $90, $00, $00, $01, $00, $1F, $FF, $FF, $F0, $10, $01, $FF, $FC, $04, $00, $00
    db $00, $00, $FF, $C9, $FF, $FC, $00, $00, $7F, $FF, $20, $03, $FF, $FF, $FF, $FF
    db $A0, $00, $02, $AA, $00, $3F, $FF, $FF, $F2, $A0, $01, $FF, $FC, $A8, $00, $00
    db $00, $00, $FF, $D1, $FF, $FC, $00, $00, $7F, $FF, $40, $03, $FF, $FF, $FF, $FF
    db $90, $00, $01, $55, $00, $5F, $FF, $FF, $F5, $50, $01, $FF, $FD, $54, $00, $00
    db $00, $00, $FF, $C9, $FF, $FC, $80, $00, $7F, $FF, $20, $03, $FF, $FF, $FF, $FF
    db $A0, $00, $00, $00, $00, $1F, $FF, $FF, $F2, $00, $01, $FF, $FC, $80, $00, $00
    db $00, $00, $FF, $D1, $FF, $FD, $00, $00, $7F, $FF, $40, $03, $FF, $FF, $FF, $FF
    db $90, $00, $00, $00, $00, $1F, $FF, $FF, $F4, $00, $01, $FF, $FD, $00, $00, $00
    db $00, $00, $FF, $C8, $0F, $FC, $80, $00, $7F, $FF, $20, $03, $FF, $00, $01, $FF
    db $A0, $00, $00, $00, $03, $FF, $00, $01, $FF, $80, $3F, $F0, $00, $80, $00, $00
    db $00, $00, $FF, $D0, $1F, $FD, $00, $00, $7F, $FF, $40, $03, $FF, $55, $55, $FF
    db $90, $00, $00, $00, $03, $FF, $55, $55, $FF, $80, $3F, $F5, $55, $00, $00, $00
    db $00, $00, $FF, $C8, $2F, $FC, $80, $00, $7F, $FF, $20, $03, $FF, $2A, $AB, $FF
    db $A0, $00, $00, $00, $03, $FF, $2A, $AB, $FF, $80, $3F, $F2, $AA, $80, $00, $00
    db $00, $00, $FF, $D0, $0F, $FD, $00, $00, $7F, $FF, $40, $03, $FF, $40, $01, $FF
    db $90, $00, $00, $00, $03, $FF, $40, $01, $FF, $90, $3F, $F4, $00, $00, $00, $00
    db $00, $00, $FF, $C8, $0F, $FC, $80, $00, $7F, $FF, $20, $03, $FF, $20, $01, $FF
    db $A0, $00, $00, $00, $03, $FF, $20, $01, $FF, $A0, $3F, $F2, $00, $00, $00, $00
    db $00, $00, $FF, $D0, $00, $7F, $E0, $00, $7F, $FF, $40, $03, $FF, $40, $01, $FF
    db $90, $00, $00, $00, $03, $FF, $40, $01, $FF, $97, $FE, $04, $00, $00, $00, $00
    db $00, $00, $FF, $C8, $00, $FF, $E0, $00, $7F, $FF, $20, $03, $FF, $20, $01, $FF
    db $A0, $00, $00, $00, $03, $FF, $20, $01, $FF, $A7, $FE, $AA, $00, $00, $00, $00
    db $00, $00, $FF, $D0, $01, $7F, $E0, $00, $7F, $FF, $40, $03, $FF, $40, $01, $FF
    db $90, $00, $00, $00, $03, $FF, $40, $01, $FF, $97, $FE, $54, $00, $00, $00, $00
    db $00, $00, $FF, $C8, $00, $7F, $E8, $00, $7F, $FF, $20, $03, $FF, $20, $01, $FF
    db $A0, $00, $00, $00, $03, $FF, $20, $01, $FF, $A7, $FE, $80, $00, $00, $00, $00
    db $00, $00, $FF, $D0, $00, $7F, $E4, $00, $7F, $FF, $40, $03, $FF, $40, $01, $FF
    db $90, $00, $00, $00, $03, $FF, $40, $01, $FF, $97, $FE, $40, $00, $00, $00, $00
    db $00, $00, $07, $FF, $FF, $FC, $08, $00, $7F, $FF, $20, $03, $FF, $20, $01, $FF
    db $A0, $00, $00, $00, $00, $1F, $FF, $FF, $F0, $27, $FF, $FF, $FF, $FF, $00, $00
    db $00, $00, $17, $FF, $FF, $FD, $54, $00, $7F, $FF, $40, $03, $FF, $40, $01, $FF
    db $90, $00, $00, $00, $00, $5F, $FF, $FF, $F5, $57, $FF, $FF, $FF, $FF, $00, $00
    db $00, $00, $0F, $FF, $FF, $FC, $A8, $00, $7F, $FF, $20, $03, $FF, $20, $01, $FF
    db $A0, $00, $00, $00, $00, $3F, $FF, $FF, $F2, $A7, $FF, $FF, $FF, $FF, $00, $00
    db $00, $00, $07, $FF, $FF, $FD, $00, $00, $7F, $FF, $40, $03, $FF, $40, $01, $FF
    db $90, $00, $00, $00, $00, $1F, $FF, $FF, $F4, $07, $FF, $FF, $FF, $FF, $40, $00
    db $00, $00, $07, $FF, $FF, $FC, $80, $00, $7F, $FF, $20, $03, $FF, $20, $01, $FF
    db $A0, $00, $00, $00, $00, $1F, $FF, $FF, $F2, $07, $FF, $FF, $FF, $FF, $20, $00
    db $00, $00, $00, $00, $00, $01, $00, $00, $00, $00, $40, $00, $00, $40, $00, $00
    db $10, $00, $00, $00, $00, $00, $00, $00, $04, $00, $00, $00, $00, $00, $40, $00
    db $00, $00, $00, $AA, $AA, $AA, $80, $00, $0A, $AA, $A0, $00, $2A, $A0, $00, $2A
    db $A0, $00, $00, $00, $00, $02, $AA, $AA, $AA, $00, $AA, $AA, $AA, $AA, $A0, $00
    db $00, $00, $00, $55, $55, $55, $00, $00, $05, $55, $40, $00, $55, $40, $00, $15
    db $50, $00, $00, $00, $00, $01, $55, $55, $54, $00, $55, $55, $55, $55, $40, $00

; 256x32 Night Skyline + Speeding GT Car Bitmap (1024 bytes)
SplashCarBmp:
    db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    db $00, $0F, $FF, $FF, $F0, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    db $00, $00, $00, $00, $00, $0F, $FF, $FF, $C0, $00, $00, $00, $00, $00, $00, $00
    db $00, $0E, $66, $66, $70, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    db $00, $00, $00, $00, $00, $08, $00, $00, $40, $00, $00, $00, $00, $00, $00, $00
    db $00, $08, $00, $00, $10, $00, $00, $03, $FF, $FF, $F0, $00, $00, $00, $00, $00
    db $00, $00, $00, $00, $00, $08, $00, $00, $40, $00, $00, $0F, $FF, $FF, $C0, $00
    db $00, $08, $00, $00, $10, $00, $00, $02, $00, $00, $10, $00, $00, $00, $00, $00
    db $00, $00, $00, $00, $00, $0E, $66, $66, $40, $00, $00, $0E, $66, $66, $40, $00
    db $00, $0E, $66, $66, $70, $00, $00, $03, $99, $99, $90, $00, $00, $03, $FF, $F0
    db $0F, $FF, $FF, $00, $00, $0E, $66, $66, $40, $00, $00, $0E, $66, $66, $40, $00
    db $00, $0E, $66, $66, $70, $00, $00, $03, $99, $99, $90, $00, $00, $03, $99, $90
    db $08, $00, $01, $00, $00, $08, $00, $00, $40, $00, $00, $08, $00, $00, $40, $00
    db $00, $08, $00, $00, $10, $FF, $FF, $C2, $00, $00, $10, $00, $00, $02, $00, $10
    db $08, $00, $01, $00, $00, $08, $00, $00, $43, $FF, $FF, $08, $00, $00, $40, $00
    db $00, $08, $00, $00, $10, $80, $00, $42, $00, $00, $10, $00, $00, $02, $00, $10
    db $0E, $66, $67, $00, $00, $0E, $66, $66, $43, $99, $99, $0E, $66, $66, $40, $00
    db $00, $0E, $66, $66, $70, $E6, $66, $43, $99, $99, $90, $FF, $FF, $C3, $99, $90
    db $0E, $66, $67, $3F, $FF, $0E, $66, $66, $43, $99, $99, $0E, $66, $66, $40, $FF
    db $FF, $06, $66, $66, $70, $E6, $66, $43, $99, $99, $90, $E6, $66, $43, $99, $90
    db $08, $00, $01, $20, $01, $08, $00, $00, $42, $00, $01, $08, $00, $00, $07, $00
    db $00, $E0, $00, $00, $10, $80, $00, $42, $00, $00, $10, $80, $00, $42, $00, $10
    db $08, $00, $01, $20, $01, $08, $00, $00, $42, $00, $01, $08, $00, $00, $18, $FF
    db $FF, $18, $00, $00, $10, $80, $00, $42, $00, $00, $10, $80, $00, $42, $00, $10
    db $0E, $66, $67, $39, $99, $0E, $66, $66, $43, $99, $99, $0E, $66, $60, $67, $00
    db $00, $E6, $06, $66, $70, $E6, $66, $43, $99, $99, $90, $E6, $66, $43, $99, $90
    db $0E, $66, $67, $39, $99, $0E, $6F, $F6, $DB, $FD, $BF, $DE, $66, $43, $FF, $FF
    db $FF, $FF, $C2, $66, $70, $E6, $66, $43, $99, $99, $90, $E6, $66, $43, $99, $90
    db $08, $00, $01, $20, $01, $08, $00, $00, $42, $00, $01, $08, $00, $0F, $FF, $FF
    db $FF, $FF, $F0, $00, $10, $80, $00, $42, $00, $00, $10, $80, $00, $42, $00, $10
    db $08, $00, $01, $20, $B7, $DB, $6D, $B6, $DB, $6D, $B7, $08, $00, $1E, $3F, $FF
    db $FF, $FC, $78, $00, $10, $80, $00, $42, $00, $00, $10, $80, $00, $42, $00, $10
    db $0E, $66, $67, $39, $99, $0E, $66, $66, $43, $99, $99, $0E, $66, $3E, $7F, $FF
    db $FF, $FE, $7C, $66, $70, $E6, $66, $43, $99, $99, $90, $E6, $66, $43, $99, $90
    db $0E, $66, $67, $39, $99, $0E, $66, $F6, $DB, $FD, $BF, $DE, $66, $3F, $FF, $FF
    db $FF, $FF, $FC, $66, $70, $E6, $66, $43, $99, $99, $90, $E6, $66, $43, $99, $90
    db $08, $00, $01, $20, $01, $08, $00, $00, $42, $00, $01, $08, $00, $1F, $3C, $00
    db $00, $3C, $F8, $00, $10, $80, $00, $42, $00, $00, $10, $80, $00, $42, $00, $10
    db $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $8E, $7E, $7F
    db $FE, $7E, $71, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
    db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $7E, $00
    db $00, $7E, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $3C, $00
    db $00, $3C, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    db $FF, $00, $FF, $00, $FF, $00, $FF, $00, $FF, $00, $FF, $00, $FF, $00, $FF, $00
    db $FF, $00, $FF, $00, $FF, $00, $FF, $00, $FF, $00, $FF, $00, $FF, $00, $FF, $00
    db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    db $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
    db $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
