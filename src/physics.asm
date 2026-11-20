; =============================================================================
; src/physics.asm — Input, Car Driving Physics, Collision, Camera, Checkpoints
; =============================================================================

; -----------------------------------------------------------------------------
; ReadInput
; Reads ZX Spectrum keyboard matrix and packs active-HIGH flags into InputState:
;   bit 0 ($01): Gas         (W, Q, 7/Up)
;   bit 1 ($02): Brake/Rev   (S, Z, 6/Down)
;   bit 2 ($04): Steer Left  (A, O, 5/Left)
;   bit 3 ($08): Steer Right (D, P, 8/Right)
;   bit 4 ($10): Handbrake   (SPACE)
;   bit 5 ($20): Toggle Cam  (C, V)
;   bit 6 ($40): Toggle Muted(M)
; -----------------------------------------------------------------------------
ReadInput:
    ld c, 0             ; C accumulates InputState

    ; Row $FBFE: Q(0), W(1), E(2), R(3), T(4)
    ld a, $FB
    in a, ($FE)
    and $03             ; Q or W pressed? (0 = pressed)
    cp $03
    jr z, .no_qw
    set 0, c            ; Gas
.no_qw:

    ; Row $FDFE: A(0), S(1), D(2), F(3), G(4)
    ld a, $FD
    in a, ($FE)
    bit 0, a
    jr nz, .no_a
    set 2, c            ; Left
.no_a:
    bit 1, a
    jr nz, .no_s
    set 1, c            ; Brake/Rev
.no_s:
    bit 2, a
    jr nz, .no_d
    set 3, c            ; Right
.no_d:

    ; Row $FEFE: CAPS(0), Z(1), X(2), C(3), V(4)
    ld a, $FE
    in a, ($FE)
    bit 1, a
    jr nz, .no_z
    set 1, c            ; Brake/Rev
.no_z:
    and $18             ; C(3) or V(4)?
    cp $18
    jr z, .no_cv
    set 5, c            ; Toggle Camera
.no_cv:

    ; Row $DFFE: P(0), O(1), I(2), U(3), Y(4)
    ld a, $DF
    in a, ($FE)
    bit 0, a
    jr nz, .no_p
    set 3, c            ; Right
.no_p:
    bit 1, a
    jr nz, .no_o
    set 2, c            ; Left
.no_o:

    ; Row $7FFE: SPACE(0), SYM(1), M(2), N(3), B(4)
    ld a, $7F
    in a, ($FE)
    bit 0, a
    jr nz, .no_sp
    set 4, c            ; Handbrake / Drift
.no_sp:
    bit 2, a
    jr nz, .no_m
    set 6, c            ; Toggle Sound
.no_m:

    ; Row $F7FE: 1(0), 2(1), 3(2), 4(3), 5/Left(4)
    ld a, $F7
    in a, ($FE)
    bit 4, a
    jr nz, .no_5
    set 2, c            ; Left
.no_5:

    ; Row $EFFE: 0(0), 9(1), 8/Right(2), 7/Up(3), 6/Down(4)
    ld a, $EF
    in a, ($FE)
    bit 2, a
    jr nz, .no_8
    set 3, c            ; Right
.no_8:
    bit 3, a
    jr nz, .no_7
    set 0, c            ; Gas
.no_7:
    bit 4, a
    jr nz, .no_6
    set 1, c            ; Brake/Rev
.no_6:

    ld a, c
    ld (InputState), a
    ret

; -----------------------------------------------------------------------------
; WaitAnyKey
; Returns NZ if any key on the keyboard is pressed, Z if no key pressed.
; -----------------------------------------------------------------------------
CheckAnyKey:
    xor a               ; $00FE scans all 8 half-rows simultaneously!
    in a, ($FE)
    and $1F
    cp $1F              ; $1F means all 5 bits HIGH = no key pressed
    ret

; -----------------------------------------------------------------------------
; UpdatePhysics
; Updates camera toggle, car speed, steering, movement, wall-sliding collision,
; 3rd-person chase camera placement, and checkpoint triggers.
; -----------------------------------------------------------------------------
UpdatePhysics:
    ld a, (InputState)
    ld e, a             ; E = InputState throughout

    ; --- Camera Toggle (C / V) with debounce ---
    bit 5, e
    jr z, .cam_released
    ld a, (CamDebounce)
    or a
    jr nz, .cam_done
    ld a, 1
    ld (CamDebounce), a
    ld a, (CamMode)
    xor 1
    ld (CamMode), a
    ld a, 1
    ld (OverlayDirty), a        ; Redraw background + overlay cleanly if toggled on briefing!
    ; Short click beep
    push de
    ld b, 12
    ld c, 40
    call PlayTone
    pop de
    jr .cam_done
.cam_released:
    xor a
    ld (CamDebounce), a
.cam_done:

    ; --- Sound Toggle (M) with debounce ---
    bit 6, e
    jr z, .snd_released
    ld a, (SoundDebounce)
    or a
    jr nz, .snd_done
    ld a, 1
    ld (SoundDebounce), a
    ld a, (SoundEnabled)
    xor 1
    ld (SoundEnabled), a
    jr .snd_done
.snd_released:
    xor a
    ld (SoundDebounce), a
.snd_done:

    ; --- Dispatch non-driving story/fail/victory overlay states ---
    ld a, (GameState)
    cp STATE_DRIVING
    jp nz, HandleOverlayState

    ; --- Check ground tile under car (for off-road grass drag) ---
    ld a, (CarX + 1)
    ld b, a
    ld a, (CarY + 1)
    ld c, a
    push de
    call GetMapTile
    pop de
    cp TILE_GRASS
    ld a, 0
    jr nz, .not_grass
    inc a
.not_grass:
    ld (CarOnGrass), a

    ; --- Acceleration, Braking, Reverse, Handbrake, Friction ---
    xor a
    ld (CarBraking), a

    ld a, (CarSpeed)
    ld b, a             ; B = current signed speed (-36..+104)

    ; Handbrake (SPACE) slows forward/reverse speed rapidly
    bit 4, e
    jr z, .no_handbrake
    ld a, 1
    ld (CarBraking), a
    ld a, b
    or a
    jp z, .speed_done
    jp m, .hb_rev
    sub 5
    jp p, .hb_store
    xor a
.hb_store:
    ld b, a
    jp .speed_done
.hb_rev:
    add a, 5
    jp m, .hb_store
    xor a
    ld b, a
    jr .speed_done

.no_handbrake:
    ; Gas pressed?
    bit 0, e
    jr z, .check_brake
    ld a, b
    add a, 4            ; Accelerate +4
    ; Check max speed (104 on road, 64 on grass)
    ld c, 104
    ld a, (CarOnGrass)
    or a
    jr z, .max_ok
    ld c, 64
.max_ok:
    ld a, b
    add a, 4
    ; Signed compare with C (both positive when fast)
    bit 7, a
    jr nz, .store_gas   ; Still reversing, let it climb toward 0
    cp c
    jr c, .store_gas
    ld a, c
.store_gas:
    ld b, a
    jr .check_grass_cap

.check_brake:
    bit 1, e
    jr z, .coast_friction
    ld a, 1
    ld (CarBraking), a
    ld a, b
    or a
    jp m, .rev_accel
    jr z, .rev_accel
    ; Braking from forward motion (-6)
    sub 6
    jp p, .brk_store
    xor a
.brk_store:
    ld b, a
    jr .speed_done
.rev_accel:
    ; Accelerating in reverse (down to -36)
    sub 3
    cp -36              ; signed: $DC
    jr nc, .brk_store   ; if >= -36 (unsigned >= $DC while negative)
    ld a, -36
    ld b, a
    jr .speed_done

.coast_friction:
    ld a, b
    or a
    jr z, .speed_done
    jp m, .coast_neg
    sub 2
    jp p, .coast_store
    xor a
.coast_store:
    ld b, a
    jr .check_grass_cap
.coast_neg:
    add a, 2
    jp m, .coast_store
    xor a
    ld b, a
    jr .speed_done

.check_grass_cap:
    ; If on grass and speed > 64, gently drag down
    ld a, (CarOnGrass)
    or a
    jr z, .speed_done
    ld a, b
    bit 7, a
    jr nz, .speed_done
    cp 65
    jr c, .speed_done
    sub 3
    ld b, a

.speed_done:
    ld a, b
    ld (CarSpeed), a

    ; --- Steering (velocity-dependent + drift boost with SPACE) ---
    xor a
    ld (CarSteer), a

    ; Check left / right keys
    ld d, 0             ; D = steer intent (-1, 0, +1)
    bit 2, e
    jr z, .chk_right
    ld d, -1
    jr .got_steer
.chk_right:
    bit 3, e
    jr z, .got_steer
    ld d, 1
.got_steer:
    ld a, d
    ld (CarSteer), a
    or a
    jr z, .steer_done

    ; Determine turn rate from speed (and allow slow pivot at speed 0? Better: tiny turn at 0 so user sees response, stronger when moving!)
    ld a, (CarSpeed)
    or a
    jr z, .steer_idle
    jp m, .steer_rev

    ; Moving forward: turn rate = 4 (or 7 if drifting with SPACE, or 3 if slow)
    cp 16
    jr c, .steer_slow
    ld c, 4
    bit 4, e            ; Handbrake drift?
    jr z, .apply_turn
    ld c, 7
    jr .apply_turn
.steer_slow:
    ld c, 3
    jr .apply_turn
.steer_idle:
    ; Very gentle steering even when stopped so player can aim easily
    ld c, 2
    jr .apply_turn
.steer_rev:
    ; Reversing flips steer direction
    ld a, d
    neg
    ld d, a
    ld c, 3

.apply_turn:
    ld a, (CarAngle)
    bit 7, d
    jr nz, .turn_left
    add a, c
    jr .store_angle
.turn_left:
    sub c
.store_angle:
    ld (CarAngle), a
.steer_done:

    ; --- Compute velocity vector & apply smooth wall-sliding collision ---
    ld a, (CarSpeed)
    or a
    jp z, .move_done

    ; dx = (CarSpeed * CosTable[CarAngle]) >> 8
    ld a, (CarAngle)
    ld l, a
    ld h, high(SinTable)
    ; CosTable = SinTable + 64 (note SinTable is 320 bytes at $B800..$B93F)
    ld de, CosTable
    ld h, 0
    add hl, de
    ld e, (hl)          ; E = cos(CarAngle) signed
    ld a, (CarSpeed)
    ld d, a             ; D = CarSpeed signed
    call MulS8xS8_Shr8  ; HL = signed dx (in 8.8 fractional units)
    ld de, (CarX)
    add hl, de
    ld (NewPosX), hl

    ; Test collision for (NewPosX, CarY)
    ld de, (CarY)
    call CheckCarCollision
    jr nz, .hit_x
    ld hl, (NewPosX)
    ld (CarX), hl
    jr .do_move_y
.hit_x:
    call DampSpeedOnHit

.do_move_y:
    ; dy = (CarSpeed * SinTable[CarAngle]) >> 8
    ld a, (CarAngle)
    ld l, a
    ld h, high(SinTable)
    ld e, (hl)          ; E = sin(CarAngle) signed
    ld a, (CarSpeed)
    ld d, a
    call MulS8xS8_Shr8  ; HL = signed dy
    ld de, (CarY)
    add hl, de
    ld (NewPosY), hl

    ; Test collision for (CarX, NewPosY)
    ex de, hl           ; DE = NewPosY
    ld hl, (CarX)       ; HL = CarX
    call CheckCarCollision
    jr nz, .hit_y
    ld hl, (NewPosY)
    ld (CarY), hl
    jr .move_done
.hit_y:
    call DampSpeedOnHit

.move_done:
    ; --- Update Camera Position (1P at Car, 3P trailing behind Car) ---
    call UpdateCamera

    ; --- Check Mission Arrival & Update Real-Time 50 Hz Countdown Deadline ---
    call CheckMissionArrival
    ld a, (GameState)
    cp STATE_DRIVING
    ret nz                      ; Just transitioned to Briefing or Victory!

    call UpdateMissionTimer

    ; Decrement banner timer if active
    ld a, (BannerTimer)
    or a
    ret z
    dec a
    ld (BannerTimer), a
    ret

; -----------------------------------------------------------------------------
; DampSpeedOnHit
; Gently reduces speed when scraping a wall (so car slides smoothly)
; -----------------------------------------------------------------------------
DampSpeedOnHit:
    ld a, (CarSpeed)
    sra a               ; / 2
    ld b, a
    sra a               ; / 4
    add a, b            ; ~75% speed preserved while sliding
    ld (CarSpeed), a
    ret

; -----------------------------------------------------------------------------
; CheckCarCollision
; Tests 4 corners of car bounding box (radius = 44 fractional units = 0.17 tile)
; around (HL = posX 8.8, DE = posY 8.8).
; Output: Z flag SET if clear (passable), NZ if colliding with solid wall!
; -----------------------------------------------------------------------------
CAR_RADIUS EQU 44

CheckCarCollision:
    push hl
    push de

    ; Corner 1: (X - R, Y - R)
    ld bc, -CAR_RADIUS
    add hl, bc
    ld a, h
    ld (.cx1), a
    ex de, hl
    add hl, bc
    ld c, h             ; mapY1
    ld a, (.cx1)
    ld b, a             ; mapX1
    call GetMapTile
    cp TILE_SOLID_MIN
    jr nc, .blocked

    ; Corner 2: (X + R, Y - R)
    pop de
    pop hl
    push hl
    push de
    ld bc, CAR_RADIUS
    add hl, bc
    ld a, h
    ld (.cx1), a
    ex de, hl
    ld bc, -CAR_RADIUS
    add hl, bc
    ld c, h
    ld a, (.cx1)
    ld b, a
    call GetMapTile
    cp TILE_SOLID_MIN
    jr nc, .blocked

    ; Corner 3: (X - R, Y + R)
    pop de
    pop hl
    push hl
    push de
    ld bc, -CAR_RADIUS
    add hl, bc
    ld a, h
    ld (.cx1), a
    ex de, hl
    ld bc, CAR_RADIUS
    add hl, bc
    ld c, h
    ld a, (.cx1)
    ld b, a
    call GetMapTile
    cp TILE_SOLID_MIN
    jr nc, .blocked

    ; Corner 4: (X + R, Y + R)
    pop de
    pop hl
    ld bc, CAR_RADIUS
    add hl, bc
    ld a, h
    ld (.cx1), a
    ex de, hl
    add hl, bc
    ld c, h
    ld a, (.cx1)
    ld b, a
    call GetMapTile
    cp TILE_SOLID_MIN
    jr nc, .blocked_no_pop

    xor a               ; Z = 1 (clear!)
    ret

.blocked:
    pop de
    pop hl
.blocked_no_pop:
    or 1                ; Z = 0 (blocked!)
    ret
.cx1: db 0

; -----------------------------------------------------------------------------
; UpdateCamera
; Sets (CamX, CamY, CamAngle).
; In 1P mode (CamMode == 1): camera sits directly at Car.
; In 3P mode (CamMode == 0): camera pulls back up to ~0.70 tiles behind Car,
; stopping short of any solid wall behind the car.
; -----------------------------------------------------------------------------
UpdateCamera:
    ld a, (CarAngle)
    ld (CamAngle), a

    ld hl, (CarX)
    ld (CamX), hl
    ld hl, (CarY)
    ld (CamY), hl

    ld a, (CamMode)
    or a
    ret nz              ; 1P mode: done!

    ; 3P mode: step backwards 4 times by ~0.175 tile (-45 * cos/sin >> 7)
    ; Compute per-step offset: stepBackX = (-45 * cos(a)) >> 8 (actually ~ -44/256 = -0.17 tile)
    ; Wait: cos is -127..+127. (-88 * cos) >> 8 = -44..+44 fractional units per step!
    ld a, (CarAngle)
    ld l, a
    ld h, 0
    ld de, CosTable
    add hl, de
    ld e, (hl)
    ld d, -88
    call MulS8xS8_Shr8  ; HL = stepBackX (~ -44..+44)
    ld (.stepX), hl

    ld a, (CarAngle)
    ld l, a
    ld h, high(SinTable)
    ld e, (hl)
    ld d, -88
    call MulS8xS8_Shr8  ; HL = stepBackY
    ld (.stepY), hl

    ld b, 4             ; 4 steps = ~0.68 tile chase distance
.cam_step_loop:
    push bc
    ld hl, (CamX)
    ld de, (.stepX)
    add hl, de
    ld (.tryX), hl

    ld hl, (CamY)
    ld de, (.stepY)
    add hl, de
    ld (.tryY), hl

    ; Check if (.tryX, .tryY) with margin is clear
    ex de, hl           ; DE = tryY
    ld hl, (.tryX)      ; HL = tryX
    call CheckCarCollision
    pop bc
    ret nz              ; Hit wall behind car — keep last safe CamX/CamY!

    ld hl, (.tryX)
    ld (CamX), hl
    ld hl, (.tryY)
    ld (CamY), hl
    djnz .cam_step_loop
    ret

.stepX: dw 0
.stepY: dw 0
.tryX:  dw 0
.tryY:  dw 0

; -----------------------------------------------------------------------------
; HandleOverlayState
; Runs when GameState is STATE_BRIEFING, STATE_FAILED, or STATE_VICTORY.
; Keeps camera synced, decrements OverlayHold anti-skip delay, and on
; Gas (bit 0) or SPACE (bit 4) resumes driving / retries / restarts campaign!
; Input: E = InputState
; -----------------------------------------------------------------------------
HandleOverlayState:
    call UpdateCamera
    ; Keep LastSysFrame synced so timer doesn't jump when resuming!
    ld a, (SYS_FRAMES)
    ld (LastSysFrame), a
    xor a
    ld (SubSecTicks), a

    ld a, (OverlayHold)
    or a
    jr z, .wait_go
    dec a
    ld (OverlayHold), a
    ret

.wait_go:
    ; Reload InputState (UpdateCamera clobbers DE!) and wait for Gas or SPACE
    ld a, (InputState)
    and $11                     ; bit 0 (Gas) or bit 4 (SPACE)
    ret z

    ld a, (GameState)
    cp STATE_BRIEFING
    jr z, .start_leg
    cp STATE_FAILED
    jr z, .retry_from_safe

    ; STATE_VICTORY -> restart full 6-chapter campaign!
    call ResetCampaign
    ret

.retry_from_safe:
    ; Restore car back to previous checkpoint & reload leg deadline!
    call RestoreSafeCheckpoint
    call LoadMission
    ld a, STATE_BRIEFING
    ld (GameState), a
    ld a, 15                    ; ~0.3s at 50 Hz
    ld (OverlayHold), a
    ld a, 1
    ld (OverlayDirty), a
    ret

.start_leg:
    ld a, STATE_DRIVING
    ld (GameState), a
    ld a, (SYS_FRAMES)
    ld (LastSysFrame), a
    xor a
    ld (SubSecTicks), a
    ; Short launch chirp
    ld b, 16
    ld c, 36
    call PlayTone
    ret

; -----------------------------------------------------------------------------
; UpdateMissionTimer
; Ticks MissionTimer down at exact 1.00 real second intervals using the
; 48K ZX Spectrum 50 Hz ROM VBlank counter at SYS_FRAMES ($5C78).
; Triggers STATE_FAILED if timer reaches 00!
; -----------------------------------------------------------------------------
UpdateMissionTimer:
    ld a, (SYS_FRAMES)
    ld b, a
    ld hl, LastSysFrame
    sub (hl)                    ; Elapsed 50 Hz VBlanks since last frame
    ld (hl), b
    ld hl, SubSecTicks
    add a, (hl)
    ld (hl), a
.sec_loop:
    cp 50                       ; 50 VBlanks = 1.00 real second!
    ret c
    sub 50
    ld (hl), a

    ; Decrement MissionTimer
    ld a, (MissionTimer)
    or a
    jr z, .time_up
    dec a
    ld (MissionTimer), a
    jr z, .time_up

    ; Urgent warning pip during final 5 seconds!
    cp 6
    jr nc, .chk_more_secs
    push hl
    ld b, 10
    ld c, 28
    call PlayTone
    pop hl
.chk_more_secs:
    ld a, (hl)
    jr .sec_loop

.time_up:
    ; DEADLINE MISSED! Return player to previous checkpoint on retry!
    xor a
    ld (CarSpeed), a
    ld (CarSteer), a
    ld a, STATE_FAILED
    ld (GameState), a
    ld a, 18                    ; ~0.36s at 50 Hz
    ld (OverlayHold), a
    ld a, 1
    ld (OverlayDirty), a
    ; Dramatic descending fail buzzer
    ld b, 28
    ld c, 70
    call PlayTone
    ld b, 32
    ld c, 95
    call PlayTone
    ld b, 40
    ld c, 125
    call PlayTone
    ret

; -----------------------------------------------------------------------------
; CheckMissionArrival
; Checks if player car is within 1 tile of active mission destination.
; Saves safe checkpoint, awards time bonus, and advances storyline!
; -----------------------------------------------------------------------------
CheckMissionArrival:
    ld a, (CarX + 1)
    ld hl, CurCheckX
    sub (hl)
    jr nc, .dx_pos
    neg
.dx_pos:
    cp 2                        ; |dx| <= 1?
    ret nc

    ld a, (CarY + 1)
    ld hl, CurCheckY
    sub (hl)
    jr nc, .dy_pos
    neg
.dy_pos:
    cp 2                        ; |dy| <= 1?
    ret nc

    ; === MISSION LEG COMPLETE! ===
    ; Save this completed checkpoint as the respawn safe point!
    call SaveSafeCheckpoint

    ; Stop car cleanly for the radio dispatch
    xor a
    ld (CarSpeed), a
    ld (CarSteer), a

    ; Score += 150 + (MissionTimer * 8)
    ld a, (MissionTimer)
    ld l, a
    ld h, 0
    add hl, hl
    add hl, hl
    add hl, hl                  ; * 8
    ld de, 150
    add hl, de
    ld de, (Score)
    add hl, de
    ld (Score), hl

    ; Advance CurMissionIdx
    ld a, (CurMissionIdx)
    inc a
    cp NUM_MISSIONS
    jr c, .next_mission

    ; === ALL 6 CHAPTERS / 12 LEGS COMPLETE -> VICTORY! ===
    ld a, STATE_VICTORY
    ld (GameState), a
    ld a, 20                    ; ~0.4s at 50 Hz
    ld (OverlayHold), a
    ld a, 1
    ld (OverlayDirty), a
    ; Celebratory 4-note victory fanfare
    ld b, 24 : ld c, 52 : call PlayTone
    ld b, 24 : ld c, 42 : call PlayTone
    ld b, 24 : ld c, 34 : call PlayTone
    ld b, 38 : ld c, 26 : call PlayTone
    ret

.next_mission:
    ld (CurMissionIdx), a
    call LoadMission
    ld a, STATE_BRIEFING
    ld (GameState), a
    ld a, 18                    ; ~0.36s at 50 Hz
    ld (OverlayHold), a
    ld a, 1
    ld (OverlayDirty), a

    ; Crisp 3-note pickup/delivery confirmation chime
    ld b, 20 : ld c, 55 : call PlayTone
    ld b, 20 : ld c, 42 : call PlayTone
    ld b, 26 : ld c, 32 : call PlayTone
    ret

; -----------------------------------------------------------------------------
; SaveSafeCheckpoint / RestoreSafeCheckpoint
; -----------------------------------------------------------------------------
SaveSafeCheckpoint:
    ld hl, (CarX)
    ld (SafeCarX), hl
    ld hl, (CarY)
    ld (SafeCarY), hl
    ld a, (CarAngle)
    ld (SafeCarAngle), a
    ret

RestoreSafeCheckpoint:
    ld hl, (SafeCarX)
    ld (CarX), hl
    ld hl, (SafeCarY)
    ld (CarY), hl
    ld a, (SafeCarAngle)
    ld (CarAngle), a
    xor a
    ld (CarSpeed), a
    ld (CarSteer), a
    call UpdateCamera
    ret

; -----------------------------------------------------------------------------
; LoadMission
; Loads CurCheckX, CurCheckY, MissionDeadline, MissionTimer, MissionIsDeliv
; from MissionMeta[CurMissionIdx] (4 bytes per entry).
; -----------------------------------------------------------------------------
LoadMission:
    ld a, (CurMissionIdx)
    add a, a
    add a, a                    ; * 4 bytes per mission
    ld e, a
    ld d, 0
    ld hl, MissionMeta
    add hl, de
    ld a, (hl)
    ld (CurCheckX), a
    inc hl
    ld a, (hl)
    ld (CurCheckY), a
    inc hl
    ld a, (hl)
    ld (MissionDeadline), a
    ld (MissionTimer), a
    inc hl
    ld a, (hl)
    ld (MissionIsDeliv), a
    xor a
    ld (SubSecTicks), a
    ld a, (SYS_FRAMES)
    ld (LastSysFrame), a
    ret

; -----------------------------------------------------------------------------
; ResetCampaign
; Resets player to start of Chapter 1 on Grand Boulevard with fresh score.
; -----------------------------------------------------------------------------
ResetCampaign:
    ld hl, $1000                ; X = 16.0
    ld (CarX), hl
    ld hl, $1880                ; Y = 24.5
    ld (CarY), hl
    ld a, 192                   ; Facing North
    ld (CarAngle), a
    xor a
    ld (CarSpeed), a
    ld (CarSteer), a
    ld (CurMissionIdx), a
    ld hl, 0
    ld (Score), hl
    call SaveSafeCheckpoint
    call LoadMission
    call UpdateCamera
    ld a, STATE_BRIEFING
    ld (GameState), a
    ld a, 15
    ld (OverlayHold), a
    ld a, 1
    ld (OverlayDirty), a
    ret

; -----------------------------------------------------------------------------
; PlayTone
; Short ZX Spectrum ULA beeper tone (preserves border color = black).
; Input: B = number of half-cycles, C = pitch delay (smaller = higher pitch)
; -----------------------------------------------------------------------------
PlayTone:
    ld a, (SoundEnabled)
    or a
    ret z
    di
    ld a, 0
.pt_loop:
    xor $10             ; Toggle EAR bit (bit 4), keep border = 0 (black)
    out ($FE), a
    ld d, c
.pt_dly:
    dec d
    jr nz, .pt_dly
    djnz .pt_loop
    xor a
    out ($FE), a
    ei
    ret
