; NES Picture Processing Unit (PPU) Constants and Macros
; See: https://www.nesdev.org/wiki/PPU_registers

; PPU Registers

; Controller ($2000) > write
;
; 7654 3210
; |||| ||||
; |||| ||++- Base nametable address
; |||| ||    (0 = $2000; 1 = $2400; 2 = $2800; 3 = $2C00)
; |||| |+--- VRAM address increment per CPU read/write of PPUDATA
; |||| |     (0: add 1, going across; 1: add 32, going down)
; |||| +---- Sprite pattern table address for 8x8 sprites
; ||||       (0: $0000; 1: $1000; ignored in 8x16 mode)
; |||+------ Background pattern table address (0: $0000; 1: $1000)
; ||+------- Sprite size (0: 8x8; 1: 8x16)
; |+-------- PPU master/slave select
; |          (0: read backdrop from EXT pins; 1: output color on EXT pins)
; +--------- Generate an NMI at the start of the
;            vertical blanking interval (0: off; 1: on)
;
; Equivalently, bits 0 and 1 are the most significant bit of the scrolling
; coordinates (see Nametables and PPU scroll):
;
; 7654 3210
;        ||
;        |+- 1: Add 256 to the X scroll position
;        +-- 1: Add 240 to the Y scroll position
PPU_CTRL = $2000
PPUCTRL  = PPU_CTRL

; Mask ($2001) > write
;
; 76543210
; ||||||||
; |||||||+- Grayscale (0: normal color; 1: produce a monochrome display)
; ||||||+-- 1: Show background in leftmost 8 pixels of screen; 0: Hide
; |||||+--- 1: Show sprites in leftmost 8 pixels of screen; 0: Hide
; ||||+---- 1: Show background
; |||+----- 1: Show sprites
; ||+------ Intensify reds (and darken other colors)
; |+------- Intensify greens (and darken other colors)
; +-------- Intensify blues (and darken other colors)
PPU_MASK = $2001
PPUMASK  = PPU_MASK

; Status ($2002) < read
;
; 7654 3210
; |||| ||||
; |||+-++++- Least significant bits previously written into a PPU register
; |||        (due to register not being updated for this address)
; ||+------- Sprite overflow. The intent was for this flag to be set
; ||         whenever more than eight sprites appear on a scanline, but a
; ||         hardware bug causes the actual behavior to be more complicated
; ||         and generate false positives as well as false negatives; see
; ||         PPU sprite evaluation. This flag is set during sprite
; ||         evaluation and cleared at dot 1 (the second dot) of the
; ||         pre-render line.
; |+-------- Sprite 0 Hit.  Set when a nonzero pixel of sprite 0 overlaps
; |          a nonzero background pixel; cleared at dot 1 of the pre-render
; |          line.  Used for raster timing.
; +--------- Vertical blank has started (0: not in VBLANK; 1: in VBLANK).
;            Set at dot 1 of line 241 (the line *after* the post-render
;            line); cleared after reading $2002 and at dot 1 of the
;            pre-render line.
PPU_STATUS = $2002
PPUSTATUS  = PPU_STATUS

; OAM address ($2003) > write / OAM data ($2004) > write
; Set the "sprite" address using OAMADDR ($2003)
; Then write the following bytes via OAMDATA ($2004)
OAM_ADDR  = $2003
OAMADDR   = OAM_ADDR
OAM_DATA	= $2004
OAMDATA   = OAM_DATA
OAM_DMA   = $4014
OAMDMA    = OAM_DMA

; - Byte 0 (Y Position)
OAM_Y    = 0

; - Byte 1 (Tile Index)
;
; 76543210
; ||||||||
; |||||||+- Bank ($0000 or $1000) of tiles
; +++++++-- Tile number of top of sprite (0 to 254; bottom half gets the next tile)
OAM_TILE = 1

; - Byte 2 (Attributes)
;
; 76543210
; ||||||||
; ||||||++- Palette (4 to 7) of sprite
; |||+++--- Unimplemented
; ||+------ Priority (0: in front of background; 1: behind background)
; |+------- Flip sprite horizontally
; +-------- Flip sprite vertically
OAM_ATTR = 2

; - Byte 3 (X Position)
OAM_X    = 3

; Scroll ($2005) >> write x2
; http://wiki.nesdev.com/w/index.php/The_skinny_on_NES_scrolling#2006-2005-2005-2006_example
PPU_SCROLL	= $2005
PPUSCROLL   = PPU_SCROLL

; Address ($2006) >> write x2
PPU_ADDR		= $2006
PPUADDR     = PPU_ADDR

; Data ($2007) <> read/write
PPU_DATA		= $2007
PPUDATA     = PPU_DATA

; ------------------------------------------------------------------------------
; APU Registers (Audio Processing Unit)
; ------------------------------------------------------------------------------

; --- Pulse Channel 1 ---
PULSE1_CTRL   = $4000   ; Pulse 1 Control. Sets duty cycle, length counter halt, constant volume/envelope, and volume level.
SQ1_VOL       = PULSE1_CTRL ; Alias

PULSE1_SWEEP  = $4001   ; Pulse 1 Sweep Unit. Configures automatic pitch slide direction, shift count, and update speed.
SQ1_SWEEP     = PULSE1_SWEEP ; Alias

PULSE1_PERIOD = $4002   ; Pulse 1 Timer Low. Sets the low 8 bits of the raw frequency/period value.
SQ1_LO        = PULSE1_PERIOD ; Alias

PULSE1_LEN    = $4003   ; Pulse 1 Timer High / Length Counter. Sets the high 3 bits of the frequency and reloads the length counter.
SQ1_HI        = PULSE1_LEN ; Alias

; --- Pulse Channel 2 ---
PULSE2_CTRL   = $4004   ; Pulse 2 Control. Sets duty cycle, length counter halt, constant volume/envelope, and volume level.
SQ2_VOL       = PULSE2_CTRL ; Alias

PULSE2_SWEEP  = $4005   ; Pulse 2 Sweep Unit. Configures automatic pitch slide direction, shift count, and update speed.
SQ2_SWEEP     = PULSE2_SWEEP ; Alias

PULSE2_PERIOD = $4006   ; Pulse 2 Timer Low. Sets the low 8 bits of the raw frequency/period value.
SQ2_LO        = PULSE2_PERIOD ; Alias

PULSE2_LEN    = $4007   ; Pulse 2 Timer High / Length Counter. Sets the high 3 bits of the frequency and reloads the length counter.
SQ2_HI        = PULSE2_LEN ; Alias

; --- Triangle Channel ---
TRI_LINEAR    = $4008   ; Triangle Linear Counter control, length counter halt flag, and linear reload values.
TRILINEAR     = TRI_LINEAR ; Alias

TRI_PERIOD    = $400A   ; Triangle Timer Low. Sets the low 8 bits of the raw triangle frequency/period value.
TRI_LO        = TRI_PERIOD ; Alias

TRI_LEN       = $400B   ; Triangle Timer High / Length Counter. Sets the high 3 bits of the frequency and reloads the length counter.
TRI_HI        = TRI_LEN  ; Alias

; --- Noise Channel ---
NOISE_CTRL    = $400C   ; Noise Control. Sets length counter halt flag, constant volume/envelope, and volume level.
NOISE_VOL     = NOISE_CTRL ; Alias

NOISE_PERIOD  = $400E   ; Noise Period Configuration. Sets random generator mode (loop noise) and sample playback rate.
NOISE_LO      = NOISE_PERIOD ; Alias

NOISE_LEN     = $400F   ; Noise Length Counter. Controls sound duration using the internal length counter decoder table.
NOISE_HI      = NOISE_LEN  ; Alias

; --- DMC (Delta Modulation Channel for Digital Samples) ---
DMC_CTRL      = $4010   ; DMC Configuration. Controls IRQ generation flag, loop sample flag, and sample frequency index.
DMC_FREQ      = DMC_CTRL ; Alias
APU_DM_CONTROL= DMC_CTRL

DMC_DATA      = $4011   ; DMC 7-bit DAC Counter. Directly alters the audio output level value for PCM playback.
DMC_RAW       = DMC_DATA ; Alias

DMC_ADDR      = $4012   ; DMC Sample Pointer address. Defines the raw starting memory location for digital audio samples.
DMC_START     = DMC_ADDR ; Alias

DMC_LEN       = $4013   ; DMC Sample Length. Configures the exact playback block size for digital audio data in memory.

; --- APU Status & IO Control ---
SND_CHN       = $4015   ; APU Channel Status. Used to instantly enable or disable sound channels, or check length counter status.
APU_STATUS    = SND_CHN ; Alias
APU_CLOCK     = SND_CHN ; Alias

JOYPAD1       = $4016   ; Controller Port 1. Strobe output line to latch buttons, and sequential data read line for Player 1.
JOY1          = JOYPAD1  ; Alias

JOYPAD2       = $4017   ; APU Frame Counter Control. Disables APU frame interrupts and selects 4-step or 5-step sound sequence mode.
JOY2_FRAME    = JOYPAD2 ; Alias
APUFRAME      = JOYPAD2 ; Joypad 2 (Read/Write)

; VRAM Addresses
NAMETABLE_A = $2000
NAMETABLE_B = $2400
NAMETABLE_C = $2800
NAMETABLE_D = $2c00
ATTR_A      = $23c0
ATTR_B      = $27c0
ATTR_C      = $2bc0
ATTR_D      = $2fc0
PALETTE     = $3f00

OBJ_0000 = $00 ; Sprite pattern table address for 8x8 sprites $0000
OBJ_1000 = $08 ; Sprite pattern table address for 8x8 sprites $1000
OBJ_8X16 = $20 ; Sprite size 8x16

BG_0000 = $00 ; Background pattern table address $0000
BG_1000 = $10 ; Background pattern table address $1000

VBLANK_NMI = $80 ; enable NMI

BG_OFF = $00 ; turn background off
BG_CLIP = $08 ; clip background
BG_ON = $0A ; turn background on

OBJ_OFF = $00 ; turn objects off
OBJ_CLIP = $10 ; clip objects
OBJ_ON = $14 ; turn objects on

.macro EnableRendering
  lda #BG_ON|OBJ_ON
  sta PPU_MASK
.endmacro

.macro DisableRendering
  lda #BG_OFF|OBJ_OFF
  sta PPU_MASK
.endmacro

.macro EnableNMI
  lda #VBLANK_NMI|BG_0000|OBJ_1000
  sta PPU_CTRL
.endmacro

.macro DisableNMI
  lda #0
  sta PPU_CTRL
.endmacro

.macro Vram address
  bit PPU_STATUS
  lda #.HIBYTE(address)
  sta PPU_ADDR
  lda #.LOBYTE(address)
  sta PPU_ADDR
.endmacro

.macro VramColRow col, row, nametable
  Vram (nametable + row*$20 + col)
.endmacro

.macro VramReset
  bit PPU_STATUS
  lda #0
  sta PPU_ADDR
  sta PPU_ADDR
.endmacro

.macro VramPalette
  bit PPU_STATUS
  lda #$3f
  sta PPU_ADDR
  lda #$00
  sta PPU_ADDR
.endmacro

.macro OAMReset
  lda #0
  sta OAM_ADDR
.endmacro

 ; Clear the screen nametable to black
.macro ClearScreen address ; address nametable
  Vram address
  lda #$00
  ldx #0
  ldy #$4
: sta PPU_DATA
  inx
  bne :-
  dey
  bne :-
.endmacro

 ; Clear the screen all nametable to black
.macro ClearScreenAll
  Vram NAMETABLE_A
  lda #$00
  ldx #0
  ldy #$10
: sta PPU_DATA
  inx
  bne :-
  dey
  bne :-
.endmacro

 ; Loading nametable from address to PPU
.macro LoadNameTable address, data ;address, data
  Vram address  ;address
  lda #data
  ldx #0
  ldy #$4
: sta PPU_DATA
  inx
  bne :-
  dey
  bne :-
.endmacro

 ; Loading palette from address to PPU
.macro LoadPalettes address
  Vram PALETTE
  ldx #0
: lda address, x
  sta PPU_DATA
  inx
  cpx #$20
  bne :-
.endmacro

 ; Loading attributes from address to PPU
.macro LoadAttributes address, data ;address_attribute , data
  Vram address
  lda #data
  ldy #$40
: sta PPU_DATA
  dey
  bne :-
.endmacro

 ; Clear all sprites data
.macro ClearSprites address ; address oam in ram
  lda #$EF
  ldx #0
: sta address, x
  inx
  bne :-
.endmacro

 ; DMA sprites loading
.macro SpriteDMA address ; address oam in ram
  pha
  lda #0
  sta OAM_ADDR
  lda #.hibyte(address)
  sta OAM_DMA
  pla
.endmacro

.macro Sprite0ClearWait
: bit PPU_STATUS
	bvs :-
.endmacro

.macro Sprite0HitWait
: bit PPU_STATUS
	bvc :-
.endmacro

.macro VblankWait
: bit PPU_STATUS
  bpl :-
.endmacro

.proc ppu_full_line
  ; Fills a full line of 32 tiles with the value in `A`.
  ldx #32
  jsr ppu_fill_line
  rts
.endproc

.proc ppu_fill_line
  ; Writes `A` into VRAM `X` times.
@loop:
  sta PPU_DATA
  dex
  bne @loop
  rts
.endproc

.proc ppu_fill_and_increment
  ; Writes the value `Y` into VRAM `X` times, incrementing `Y` after each write.
  ; Useful if you have background tiles laid out linearly in the pattern table.
@loop:
  tya
  iny
  sta PPU_DATA
  dex
  bne @loop
  rts
.endproc

; Random number generator - Simple shift based random number.
; Requires 2-byte variable 'seed' (seed+0, seed+1) in Zero Page.
; Initialize with a non-zero value.
; Returns a random 8-bit number in A (0-255), clobbers Y (unknown).

 ; Initialize seed random number
.proc random_init
  lda #%10011101
  sta <seed
  lda #%01011011
  sta <seed + 1
  rts
.endproc

.proc random
	lda seed+1
	tay
	lsr A
	lsr A
	lsr A 
	sta seed+1
	lsr A
	eor seed+1
	lsr A
	eor seed+1
	eor seed+0
	sta seed+1
	tya
	sta seed+0
	asl A
	eor seed+0
	asl A
	eor seed+0
	asl A
	asl A
	asl A
	eor seed+0
	sta seed+0
	rts
.endproc