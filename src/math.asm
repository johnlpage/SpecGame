; =============================================================================
; src/math.asm — Fast Z80 Fixed-Point Math & Map Lookup Routines
; =============================================================================

; -----------------------------------------------------------------------------
; MulU8x12_Shr8
; Computes HL = floor((A * DE) / 256)
; Precondition: A = unsigned 8-bit (0..255), DE = unsigned 12-bit (0..4095)
; Note: Since DE <= 4095, HL + DE <= 8191 < 65536, so Carry is ALWAYS 0 after
;       ADD HL, DE, making RR H / RR L an exact unsigned right shift!
; Clobbers: AF, HL (DE, BC preserved)
; -----------------------------------------------------------------------------
MulU8x12_Shr8:
    ld hl, 0
    ; Unrolled 8 bits (LSB first)
    rrca
    jr nc, .b0
    add hl, de
.b0:
    srl h
    rr l

    rrca
    jr nc, .b1
    add hl, de
.b1:
    srl h
    rr l

    rrca
    jr nc, .b2
    add hl, de
.b2:
    srl h
    rr l

    rrca
    jr nc, .b3
    add hl, de
.b3:
    srl h
    rr l

    rrca
    jr nc, .b4
    add hl, de
.b4:
    srl h
    rr l

    rrca
    jr nc, .b5
    add hl, de
.b5:
    srl h
    rr l

    rrca
    jr nc, .b6
    add hl, de
.b6:
    srl h
    rr l

    rrca
    jr nc, .b7
    add hl, de
.b7:
    srl h
    rr l
    ret

; -----------------------------------------------------------------------------
; MulU8xU8_Hi
; Computes A = floor((H * E) / 256)  (unsigned 8x8 -> high byte)
; Input:  H = unsigned 8-bit, E = unsigned 8-bit
; Output: A = (H * E) >> 8, HL = full 16-bit product
; Clobbers: AF, D, HL (B, C, E preserved)
; -----------------------------------------------------------------------------
MulU8xU8_Hi:
    ld d, 0
    ld l, d
    sla h
    jr nc, $+3
    ld l, e
    add hl, hl
    jr nc, $+3
    add hl, de
    add hl, hl
    jr nc, $+3
    add hl, de
    add hl, hl
    jr nc, $+3
    add hl, de
    add hl, hl
    jr nc, $+3
    add hl, de
    add hl, hl
    jr nc, $+3
    add hl, de
    add hl, hl
    jr nc, $+3
    add hl, de
    add hl, hl
    jr nc, $+3
    add hl, de
    ld a, h
    ret

; -----------------------------------------------------------------------------
; MulU8xS8_Shr7
; Computes signed 16-bit HL = (A_unsigned * E_signed) >> 7
; Input:  A = unsigned 8-bit (0..255)
;         E = signed 8-bit (-127..+127)
; Output: HL = signed 16-bit result (-255..+255)
; Clobbers: AF, DE, HL (BC preserved)
; -----------------------------------------------------------------------------
MulU8xS8_Shr7:
    ld h, a             ; H = unsigned multiplier
    ld a, e
    or a
    jp p, .pos
    ; Negative E: negate E, multiply, negate result
    neg
    ld e, a
    call MulU8xU8_Hi    ; HL = H * |E| (0..32385)
    ; Shift right 7 == shift left 1, take high byte (with bit 8 in carry -> 16-bit!)
    add hl, hl          ; HL = 2 * product; H = (product >> 7) & $FF, Carry = bit 15
    ld l, h
    ld a, 0
    rla                 ; A = Carry (0 or 1)
    ld h, a             ; HL = unsigned (product >> 7) in 0..253
    ; Negate HL: HL = 0 - HL
    xor a
    sub l
    ld l, a
    sbc a, a
    sub h
    ld h, a
    ret
.pos:
    ld e, a
    call MulU8xU8_Hi    ; HL = H * E (0..32385)
    add hl, hl          ; H = low byte of (product >> 7), Carry = bit 8
    ld l, h
    ld a, 0
    rla
    ld h, a
    ret

; -----------------------------------------------------------------------------
; MulS8xS8_Shr8
; Computes signed 16-bit HL = sign_extend((D_signed * E_signed) >> 8)
; Input:  D = signed 8-bit (-127..+127), E = signed 8-bit (-127..+127)
; Output: HL = signed 16-bit (in -64..+64)
; Clobbers: AF, DE, HL (BC preserved)
; -----------------------------------------------------------------------------
MulS8xS8_Shr8:
    ld a, d
    xor e
    push af             ; Save result sign in bit 7 of A on stack
    ld a, d
    or a
    jp p, .dpos
    neg
.dpos:
    ld h, a
    ld a, e
    or a
    jp p, .epos
    neg
.epos:
    ld e, a
    call MulU8xU8_Hi    ; A = H = (|D| * |E|) >> 8 (0..63)
    pop de              ; D has sign bit
    bit 7, d
    jr z, .respos
    neg
    ld l, a
    ld h, $FF
    or a
    ret nz
    ld h, 0
    ret
.respos:
    ld l, a
    ld h, 0
    ret

; -----------------------------------------------------------------------------
; GetMapTile
; Looks up tile at (B = mapX, C = mapY) in 32x32 WorldMap ($D000).
; Out-of-bounds returns 10 (perimeter guardrail).
; Input:  B = mapX (0..31), C = mapY (0..31)
; Output: A = tile ID (0..10)
; Clobbers: AF, HL (BC, DE preserved)
; -----------------------------------------------------------------------------
GetMapTile:
    ld a, b
    cp 32
    jr nc, .oob
    ld a, c
    cp 32
    jr nc, .oob
    rrca
    rrca
    rrca
    ld h, a
    and $E0
    or b
    ld l, a
    ld a, h
    and $03
    or $D0
    ld h, a
    ld a, (hl)
    ret
.oob:
    ld a, 10
    ret
