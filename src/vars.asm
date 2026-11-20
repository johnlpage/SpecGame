; =============================================================================
; src/vars.asm — Constants, Buffer Addresses, and Game State Variables
; =============================================================================

; --- Off-screen Buffers (Uncontended RAM $C000-$CBFF) ---
VBUF_PX         EQU $C000       ; 32 * 64 = 2048 bytes (rows 0..63 -> screen Y=8..135)
VBUF_ATTR       EQU $C800       ; 32 * 16 = 512 bytes  (char rows 1..16 -> $5820..$5A1F)

RAY_ZBUF        EQU $CA00       ; 64 bytes: perpDist8 (0..255) per ray column
RAY_HEIGHT      EQU $CA40       ; 64 bytes: wall half-height (0..32 buffer rows) per ray
RAY_TILE        EQU $CA80       ; 64 bytes: wall tile (4..10) | $80 if shaded side
COL_WALL_H      EQU $CAC0       ; 32 bytes: min wall half-height of ray pair (for ground skip)
COL_WALL_ATTR   EQU $CAE0       ; 32 bytes: wall color attribute (PAPER 0 + INK + BRIGHT)

; --- Tile Types ---
TILE_ROAD       EQU 0
TILE_CROSS      EQU 1
TILE_GRASS      EQU 2
TILE_PLAZA      EQU 3
TILE_SOLID_MIN  EQU 4           ; >= 4 is solid building/wall

; --- ZX Spectrum Attribute Helpers ---
; Format: F B PPP III  (F=Flash, B=Bright, P=Paper 0..7, I=Ink 0..7)
ATTR_SKY        EQU $0D         ; Paper 1 (Blue), Ink 5 (Cyan)
ATTR_SKY_SUN    EQU $0E         ; Paper 1 (Blue, same bright=0!), Ink 6 (Yellow)
ATTR_ROAD       EQU $07         ; Paper 0 (Black), Ink 7 (White)
ATTR_CROSS      EQU $46         ; Bright Paper 0 (Black), Ink 6 (Yellow)
ATTR_GRASS      EQU $20         ; Paper 4 (Green), Ink 0 (Black)
ATTR_GRASS_DARK EQU $04         ; Paper 0 (Black), Ink 4 (Green) - for wall-edge cells
ATTR_PLAZA      EQU $05         ; Paper 0 (Black), Ink 5 (Cyan)
ATTR_HUD_TOP    EQU $4F         ; Bright Paper 1 (Blue), Ink 7 (White)
ATTR_DASH_BG    EQU $07         ; Paper 0 (Black), Ink 7 (White)

; --- Game State Variables ($CB00-$CBFF) ---
VAR_BASE        EQU $CB00

; Car position (unsigned 8.8 fixed point: high byte = tile 0..31, low byte = frac 0..255)
CarX            EQU VAR_BASE + $00  ; dw
CarY            EQU VAR_BASE + $02  ; dw
CarAngle        EQU VAR_BASE + $04  ; db (0..255: 0=E, 64=S, 128=W, 192=N)
CarSpeed        EQU VAR_BASE + $05  ; db (signed: -32..+112)
CarSteer        EQU VAR_BASE + $06  ; db (signed: -1 left, 0 straight, +1 right)
CarBraking      EQU VAR_BASE + $07  ; db (0 or 1)
CarOnGrass      EQU VAR_BASE + $08  ; db (0 or 1)

; Camera position & angle (equals Car in 1P; trails behind Car in 3P)
CamX            EQU VAR_BASE + $09  ; dw
CamY            EQU VAR_BASE + $0B  ; dw
CamAngle        EQU VAR_BASE + $0D  ; db
CamMode         EQU VAR_BASE + $0E  ; db (0 = 3rd Person Chase, 1 = 1st Person Cockpit)
CamDebounce     EQU VAR_BASE + $0F  ; db (prevents rapid toggling while holding C)

; Input state bitmask:
;   bit 0: Gas (W/Q/Up)
;   bit 1: Brake/Rev (S/Z/Down)
;   bit 2: Left (A/O/Left)
;   bit 3: Right (D/P/Right)
;   bit 4: Handbrake/Drift (Space)
;   bit 5: Toggle Cam (C)
;   bit 6: Toggle Sound (M)
InputState      EQU VAR_BASE + $10  ; db
SoundEnabled    EQU VAR_BASE + $11  ; db (1 = on, 0 = muted)
SoundDebounce   EQU VAR_BASE + $12  ; db
FrameCounter    EQU VAR_BASE + $13  ; db (increments each rendered frame)

; --- Game States ---
STATE_BRIEFING  EQU 0           ; Story Radio Dispatch overlay (press Gas/Space to go)
STATE_DRIVING   EQU 1           ; Active timed driving leg
STATE_FAILED    EQU 2           ; Deadline missed -> respawn at previous checkpoint
STATE_VICTORY   EQU 3           ; All 6 chapters completed!

; ZX Spectrum 48K 50 Hz hardware VBlank frame counter (maintained by ROM IM 1 ISR)
SYS_FRAMES      EQU $5C78

; Storyline mission & deadline state
GameState       EQU VAR_BASE + $14  ; db (0..3)
CurMissionIdx   EQU VAR_BASE + $15  ; db (0..NUM_MISSIONS-1)
CurCheckX       EQU VAR_BASE + $16  ; db (target tile X)
CurCheckY       EQU VAR_BASE + $17  ; db (target tile Y)
MissionDeadline EQU VAR_BASE + $18  ; db (starting deadline seconds)
MissionTimer    EQU VAR_BASE + $19  ; db (countdown seconds remaining)
MissionIsDeliv  EQU VAR_BASE + $1A  ; db (0=pickup, 1=delivery)
LastSysFrame    EQU VAR_BASE + $1B  ; db (last read $5C78)
SubSecTicks     EQU VAR_BASE + $1C  ; db (0..49 -> 50 Hz = 1.00 sec)
Score           EQU VAR_BASE + $1D  ; dw (0..9999)
OverlayHold     EQU VAR_BASE + $1F  ; db (brief anti-skip debounce frames)

; Saved previous checkpoint for deadline-fail respawn!
SafeCarX        EQU VAR_BASE + $55  ; dw
SafeCarY        EQU VAR_BASE + $57  ; dw
SafeCarAngle    EQU VAR_BASE + $59  ; db
BannerTimer     EQU VAR_BASE + $5A  ; db (flash timer on arrival)
OverlayDirty    EQU VAR_BASE + $5B  ; db (1 = redraw 3D scene + story overlay once)

; Raycaster scratch variables
RayCol          EQU VAR_BASE + $20  ; db (0..63)
RayAngle        EQU VAR_BASE + $21  ; db (0..255)
MapX            EQU VAR_BASE + $22  ; db
MapY            EQU VAR_BASE + $23  ; db
StepX           EQU VAR_BASE + $24  ; db (+1 or -1)
StepY           EQU VAR_BASE + $25  ; db (+1 or -1)
DeltaX          EQU VAR_BASE + $26  ; dw
DeltaY          EQU VAR_BASE + $28  ; dw
SideX           EQU VAR_BASE + $2A  ; dw
SideY           EQU VAR_BASE + $2C  ; dw
HitDist         EQU VAR_BASE + $2E  ; dw
HitSide         EQU VAR_BASE + $30  ; db (0=X-side, 1=Y-side)
HitTile         EQU VAR_BASE + $31  ; db

; Ground caster scratch variables
GndBand         EQU VAR_BASE + $32  ; db (0..15)
GndStepX        EQU VAR_BASE + $33  ; dw (signed 8.8)
GndStepY        EQU VAR_BASE + $35  ; dw (signed 8.8)
GndCurX         EQU VAR_BASE + $37  ; dw (unsigned 8.8)
GndCurY         EQU VAR_BASE + $39  ; dw (unsigned 8.8)
GndBufPtr       EQU VAR_BASE + $3B  ; dw
GndAttrPtr      EQU VAR_BASE + $3D  ; dw
GndRowY         EQU VAR_BASE + $3F  ; db (buffer row 32..62)
GndCos          EQU VAR_BASE + $40  ; db (signed)
GndSin          EQU VAR_BASE + $41  ; db (signed)

; Renderer / Wall strip scratch
RenCol          EQU VAR_BASE + $42  ; db (0..31 byte column)
LeftH           EQU VAR_BASE + $43  ; db
RightH          EQU VAR_BASE + $44  ; db
LeftTile        EQU VAR_BASE + $45  ; db
RightTile       EQU VAR_BASE + $46  ; db
LeftSkyH        EQU VAR_BASE + $47  ; db
RightSkyH       EQU VAR_BASE + $48  ; db
LeftPatPtr      EQU VAR_BASE + $49  ; dw
RightPatPtr     EQU VAR_BASE + $4B  ; dw

; Beacon projection scratch
BeaconDist      EQU VAR_BASE + $4D  ; db (perpDist8)
BeaconCol       EQU VAR_BASE + $4E  ; db (0..63 ray column, $FF if offscreen)
BeaconDir       EQU VAR_BASE + $4F  ; db (signed angle diff for HUD compass arrow)

; Physics scratch
NewPosX         EQU VAR_BASE + $50  ; dw
NewPosY         EQU VAR_BASE + $52  ; dw
PrevCamMode     EQU VAR_BASE + $54  ; db (tracks mode switches to redraw dashboard)
