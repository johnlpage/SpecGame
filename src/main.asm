; =============================================================================
; SpecDrive 3D — Open-World Raycasting Driving Game for ZX Spectrum 48K
; =============================================================================
; Features:
;   - 64-column DDA raycaster with textured, sunlit/shaded 3D city buildings
;   - Real-time perspective ground/road/grass/plaza caster with moving lane lines
;   - Scrolling distant skyline & golden sun panorama
;   - Seamless 3rd-Person Chase Car & 1st-Person Cockpit views (press C or V)
;   - 32x32 open-world city (Downtown Plaza, Central Park, Neon District,
;     Speedway Oval, Old Town, Perimeter Ring Highway) with 12 3D Checkpoints
;   - Live 32x32 city radar minimap, animated steering wheel, & arcade drift!
;
; Controls:
;   W / Q / Up(7)    : Accelerate
;   S / Z / Down(6)  : Brake / Reverse
;   A / O / Left(5)  : Steer Left
;   D / P / Right(8) : Steer Right
;   SPACE            : Handbrake / Drift
;   C / V            : Toggle 3rd-Person / 1st-Person Camera View
;   M                : Toggle Beeper Sound
; =============================================================================

    DEVICE ZXSPECTRUM48
    ORG $8000

    INCLUDE "src/vars.asm"

; -----------------------------------------------------------------------------
; Entry Point
; -----------------------------------------------------------------------------
Start:
    di
    ld sp, $7FFF                ; Stack at top of contended RAM

    call InitScreen
    call InitGameState
    ei                          ; Enable 50 Hz IM 1 VBlank interrupts

    call ShowSplashScreen       ; Iconic GTA '82 (Grand Theft Auto 0) title screen!

    call InitScreen             ; Clear splash before entering 3D city
    call InitHUD                ; Draw top bar, dashboard & monochrome radar

    ; Short release guard so the key that dismissed the splash doesn't skip Ch.1 briefing!
    ld a, 12                    ; ~0.24s at 50 Hz
    ld (OverlayHold), a
    ld a, 1
    ld (OverlayDirty), a

; -----------------------------------------------------------------------------
; Main Game Loop
; -----------------------------------------------------------------------------
MainLoop:
    call ReadInput              ; Scan keyboard (WASD / QZOP / Arrows / Space / C / M)
    call UpdatePhysics          ; Driving physics, collision, mission timer & story state

    ld a, (GameState)
    cp STATE_DRIVING
    jr z, .loop_driving

    ; --- Overlay State (Briefing / Failed / Victory): ZERO FLICKER! ---
    ; Render 3D scene + mission window ONCE when OverlayDirty != 0; otherwise
    ; just HALT (50 Hz) and pulse the monochrome map target!
    ld a, (OverlayDirty)
    or a
    jr z, .overlay_idle
    xor a
    ld (OverlayDirty), a
    call CastAllRays
    call RenderFrame
    call DrawStoryOverlay
    jr .loop_hud

.overlay_idle:
    halt                        ; Smooth 50 Hz idle (zero viewport redraw = zero flicker!)
    jr .loop_hud

.loop_driving:
    call CastAllRays            ; 32-ray DDA raycaster
    call RenderFrame            ; Sky, ground, 3D walls, VBlank blit, 1P/3P car

.loop_hud:
    call UpdateHUD              ; Speed, timer, mission, steering wheel, monochrome map

    ld hl, FrameCounter
    inc (hl)

    jr MainLoop

; -----------------------------------------------------------------------------
; InitScreen
; Clears pixel RAM ($4000-$57FF), fills attribute RAM ($5800-$5AFF),
; and sets ULA border to black.
; -----------------------------------------------------------------------------
InitScreen:
    xor a
    out ($FE), a                ; Black border

    ld hl, $4000
    ld de, $4001
    ld bc, 6143
    ld (hl), 0
    ldir

    ld hl, $5800
    ld de, $5801
    ld bc, 767
    ld (hl), $07                ; Black paper, White ink
    ldir
    ret

; -----------------------------------------------------------------------------
; InitGameState
; Places the car on South Grand Boulevard (15.5, 24.5) facing North (192)
; looking straight down the wide boulevard toward Central Spire & Checkpoint 1!
; -----------------------------------------------------------------------------
InitGameState:
    ; Zero variable area ($CB00-$CBFF)
    ld hl, VAR_BASE
    ld de, VAR_BASE + 1
    ld bc, 255
    ld (hl), 0
    ldir

    xor a
    ld (CamMode), a             ; Start in 3rd-Person Chase View (press C for 1st-Person!)
    ld a, 1
    ld (SoundEnabled), a        ; Beeper SFX on by default

    ; Start Chapter 1 ("THE LEAK" — Collect Data Tape from Harbor Plaza)
    call ResetCampaign
    ld a, 2                     ; Short initial release guard
    ld (OverlayHold), a
    ret

; -----------------------------------------------------------------------------
; Game Modules (Code & Sprites in $8000..$B1FF)
; -----------------------------------------------------------------------------
    INCLUDE "src/math.asm"
    INCLUDE "src/physics.asm"
    INCLUDE "src/raycast.asm"
    INCLUDE "src/render.asm"
    INCLUDE "src/hud.asm"
    INCLUDE "src/splash.asm"

CodeEnd:
    ASSERT CodeEnd <= $B200, "Code overflowed into Tables at $B200!"

; -----------------------------------------------------------------------------
; Precomputed Math Tables ($B200..$BCFF) & Open-World City Map ($D000..$D4FF)
; -----------------------------------------------------------------------------
    INCLUDE "src/tables.asm"
    INCLUDE "src/world.asm"

EndCode:

; =============================================================================
; BASIC Autostart Loader (embedded in .tap only, not part of CODE block)
;   10 CLEAR 32767: LOAD "" CODE : RANDOMIZE USR 32768
; =============================================================================
BasicStart:
    db 0, 10
    dw Line10End - Line10Data
Line10Data:
    db $FD, "32767", $0E, 0, 0, $FF, $7F, 0
    db ":"
    db $EF, '""', $AF
    db ":"
    db $F9, $C0, "32768", $0E, 0, 0, $00, $80, 0
    db $0D
Line10End:
BasicEnd:

; =============================================================================
; Build Outputs
; =============================================================================
    SAVEBIN "build/game.bin", Start, EndCode - Start

    EMPTYTAP "build/game.tap"
    SAVETAP "build/game.tap", BASIC, "GTA82", BasicStart, BasicEnd - BasicStart, 10
    SAVETAP "build/game.tap", CODE, "code", Start, EndCode - Start

    SAVESNA "build/game.sna", Start
