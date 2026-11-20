; =============================================================================
; src/raycast.asm — Fast 32-Column Z80 DDA Raycaster & 3D Beacon Projector
; =============================================================================

; -----------------------------------------------------------------------------
; CastAllRays
; Casts 32 rays across 90-degree FOV (CamAngle - 32 + col*2, col = 0..31).
; Each ray aligns 1:1 with a ZX Spectrum 8-pixel character column for zero
; horizontal attribute clash and high framerate!
; Fills RAY_ZBUF[0..31], RAY_HEIGHT[0..31], RAY_TILE[0..31], and projects beacon.
; -----------------------------------------------------------------------------
CastAllRays:
    ld a, (CamAngle)
    sub 31                      ; Centered symmetric 32-ray fan (-31 .. +31)
    ld (RayAngle), a
    xor a
    ld (RayCol), a

.ray_loop:
    ; --- Look up DeltaX = InvAbsCos[RayAngle] ---
    ld a, (RayAngle)
    ld l, a
    ld h, high(InvAbsCosLo)
    ld e, (hl)
    inc h                       ; InvAbsCosHi
    ld d, (hl)
    ld (DeltaX), de

    ; --- Determine StepX and initial SideX ---
    ld a, (RayAngle)
    add a, 64
    bit 7, a
    jr nz, .neg_x
    ld a, 1
    ld (StepX), a
    ld a, (CamX)
    cpl
    jr .calc_sidex
.neg_x:
    ld a, -1
    ld (StepX), a
    ld a, (CamX)
.calc_sidex:
    call MulU8x12_Shr8
    ld (SideX), hl

    ; --- Look up DeltaY = InvAbsSin[RayAngle] ---
    ld a, (RayAngle)
    ld l, a
    ld h, high(InvAbsSinLo)
    ld e, (hl)
    inc h                       ; InvAbsSinHi
    ld d, (hl)
    ld (DeltaY), de

    ; --- Determine StepY and initial SideY ---
    ld a, (RayAngle)
    bit 7, a
    jr nz, .neg_y
    ld a, 1
    ld (StepY), a
    ld a, (CamY)
    cpl
    jr .calc_sidey
.neg_y:
    ld a, -1
    ld (StepY), a
    ld a, (CamY)
.calc_sidey:
    call MulU8x12_Shr8
    ld (SideY), hl

    ; --- Fast Register-Assisted DDA Loop ---
    ; B = mapX, C = mapY, IXH = remaining steps (15), HL = SideX, DE = SideY
    ld a, (CamX + 1)
    ld b, a
    ld a, (CamY + 1)
    ld c, a
    ld ixh, 15                  ; Max 15 grid crossings (~13.5 tiles view distance)
    ld hl, (SideX)
    ld de, (SideY)

.dda_loop:
    ; Compare HL (SideX) vs DE (SideY) without destroying HL!
    push hl
    or a
    sbc hl, de
    pop hl
    jr nc, .step_y_branch

.step_x_branch:
    ; SideX < SideY -> cross vertical X grid line
    ld (HitDist), hl
    push de
    ld de, (DeltaX)
    add hl, de                  ; HL = new SideX
    pop de
    ld a, (StepX)
    add a, b
    ld b, a                     ; B = new mapX
    xor a
    ld (HitSide), a             ; 0 = X-side (sunlit)
    jr .check_hit

.step_y_branch:
    ; SideY <= SideX -> cross horizontal Y grid line
    ld (HitDist), de
    push hl
    ld hl, (DeltaY)
    add hl, de
    ex de, hl                   ; DE = new SideY
    pop hl
    ld a, (StepY)
    add a, c
    ld c, a                     ; C = new mapY
    ld a, $80
    ld (HitSide), a             ; $80 = Y-side (shaded)

.check_hit:
    ; Distance fog cutoff: if HitDist >= 14 tiles ($0E00), miss
    ld a, (HitDist + 1)
    cp 14
    jr nc, .ray_miss

    ; Bounds check & fast inline WorldMap[$D000 + C*32 + B] lookup
    ld a, b
    cp 32
    jr nc, .hit_border
    ld a, c
    cp 32
    jr nc, .hit_border

    push hl
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
    pop hl

    cp TILE_SOLID_MIN
    jr nc, .ray_hit

    dec ixh
    jr nz, .dda_loop
    jr .ray_miss

.hit_border:
    ld a, 10
.ray_hit:
    ld (HitTile), a

    ; Convert 12-bit HitDist (8.8) -> 8-bit d8 = HitDist >> 4 (16 = 1.0 tile)
    ld hl, (HitDist)
    ld a, h
    cp 16
    jr nc, .ray_miss
    rrca
    rrca
    rrca
    rrca
    and $F0
    ld b, a
    ld a, l
    rrca
    rrca
    rrca
    rrca
    and $0F
    or b
    or a
    jr nz, .d8_ok
    inc a
.d8_ok:
    ld h, a                     ; H = d8

    ; Fisheye correction: perpDist8 = (d8 * FisheyeCos[RayCol]) >> 8
    ld a, (RayCol)
    ld e, a
    ld d, high(FisheyeCos)
    ld a, (de)
    ld e, a
    call MulU8xU8_Hi            ; A = perpDist8

    ; Store RAY_ZBUF[col], RAY_HEIGHT[col], RAY_TILE[col]
    ld c, a                     ; C = perpDist8
    ld a, (RayCol)
    ld l, a
    ld h, high(RAY_ZBUF)        ; $CA00
    ld (hl), c

    ld e, c
    ld d, high(WallHeightTable)
    ld a, (de)
    ld b, a                     ; B = baseHalfH (0..32)
    ld a, l
    add a, $40                  ; $CA40 = RAY_HEIGHT
    ld l, a
    ld (hl), b

    ld a, (HitTile)
    ld d, a
    ld a, (HitSide)
    or d
    ld d, a
    ld a, l
    add a, $40                  ; $CA80 = RAY_TILE
    ld l, a
    ld (hl), d
    jr .next_ray

.ray_miss:
    ld a, (RayCol)
    ld l, a
    ld h, high(RAY_ZBUF)
    ld (hl), 255
    ld a, l
    add a, $40
    ld l, a
    ld (hl), 0
    ld a, l
    add a, $40
    ld l, a
    ld (hl), 0

.next_ray:
    ld a, (RayAngle)
    add a, 2                    ; 32 rays across 64 BAM units (90 deg FOV)
    ld (RayAngle), a
    ld hl, RayCol
    inc (hl)
    ld a, (hl)
    cp 32
    jp c, .ray_loop
    ret
