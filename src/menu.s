; It is a NES menu based on the 9999-in-1 pirate multicart with romantic story and the Unchained Melody in the menu
;-------------------------------------------------------------------------------
; System Memory Map
;-------------------------------------------------------------------------------
; $00-$1F:    Subroutine Scratch Memory
;             Volatile Memory used for parameters, return values, and temporary
;             / scratch data.
;             Region of memory used to hold game state on the zero page. Since
;             zero page memory access is faster than absolute addressing store
;             values that are frequently read/written here.
;-------------------------------------------------------------------------------
; $100-$1FF:  The Stack
;             Region of memory set aside for the system stack.
;-------------------------------------------------------------------------------
; $200-$2FF:  OAM Sprite Memory
;             This holds the OAM information for the sprites used by the game.
;             Every frame, inside the `render_loop` routine below, the data here
;             is transferred to the PPU in its entirety.
;-------------------------------------------------------------------------------
; $300-$7FF:  General Purpose RAM
;             General purpose storage for other game related state. Since this
;             demo is pretty simple none of this memory is used, so feel free
;             to use it when making modifications or hacking your own logic.
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; Switch the CPU instruction set
;-------------------------------------------------------------------------------
.setcpu "6502x"
;-------------------------------------------------------------------------------
; iNES Header and Vectors
;-------------------------------------------------------------------------------
  .if HEADER_ENABLED
.include "header.inc"
  .endif
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; Game-related configuration settings
; These values control UI behavior, input timing, and visual
; transitions. Each setting can be overridden externally
; (for example, via Makefile or command-line defines).
; If not provided, the default values below are used.
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; Button autorepeat timing
; BUTTON_REPEAT_DELAY:
;   Number of frames before autorepeat starts.
;   Default: 30 frames (~0.5 seconds at 60 FPS)
;-------------------------------------------------------------------------------
.ifndef BUTTON_REPEAT_DELAY
BUTTON_REPEAT_DELAY = 30
.endif

;-------------------------------------------------------------------------------
; BUTTON_REPEAT_RATE:
;   Number of frames between repeated button presses
;   once autorepeat is active.
;   Default: 15 frames (~0.25 seconds at 60 FPS)
;-------------------------------------------------------------------------------
.ifndef BUTTON_REPEAT_RATE
BUTTON_REPEAT_RATE = 15
.endif

;-------------------------------------------------------------------------------
; ENABLE_LAST_GAME_SAVING:
;   Enables saving the last launched game so the menu can
;   automatically highlight it next time.
;   Default: 1 (enabled)
;-------------------------------------------------------------------------------
.ifndef ENABLE_LAST_GAME_SAVING
ENABLE_LAST_GAME_SAVING = 1
.endif

;-------------------------------------------------------------------------------
; FADE_DELAY:
;   Frame counter used to control the speed of fade/dim
;   transitions in the menu UI.
;   Lower values = faster fade.
;   Default: 4 frames
;-------------------------------------------------------------------------------
.ifndef FADE_DELAY
FADE_DELAY = 4
.endif

;-------------------------------------------------------------------------------
; Macro that performs a safe include of a file.
; ca65 cannot include files via variables or strings,
; so we wrap .include inside a macro and pass the filename
; directly as a literal.
;-------------------------------------------------------------------------------
.macro INCLUDE_GAMES file
  .include file
.endmacro

;-------------------------------------------------------------------------------
; Debug fallback:
; If RUS_ENABLED is not defined at all, it means the build
; was launched manually (not through Makefile). In this case
; we load the default games.inc file.
;-------------------------------------------------------------------------------
.ifndef RUS_ENABLED
  INCLUDE_GAMES "games.inc"

;-------------------------------------------------------------------------------
; Normal build path:
; Makefile always defines RUS_ENABLED as either 1 or 0.
; If RUS_ENABLED = 1 → load Russian game list.
; If RUS_ENABLED = 0 → load English game list.
;-------------------------------------------------------------------------------
.else
  .if RUS_ENABLED
    ; Russian language enabled
    INCLUDE_GAMES "games.list_rus.inc"
  .else
    ; English language enabled
    INCLUDE_GAMES "games.list_eng.inc"
  .endif
.endif

;-------------------------------------------------------------------------------
.segment "VECTORS"
  .addr nmi, reset, 0

.segment "BANK_TABLE"
unrom_bank_data:
  ; # For compatibility with UNROM and to resolve UNROM's bus conflicts.
  ; # The byte written to the mapper must match the byte stored in ROM 
  ; # at that exact address to prevent physical bus contention on the board.
  .byte $00, $01, $02, $03, $04, $05, $06, $07, $08, $09, $0A, $0B, $0C, $0D, $0E, $0F

;-------------------------------------------------------------------------------
; 6502 Zero Page Memory (256 bytes)
;-------------------------------------------------------------------------------
.segment "ZEROPAGE"
tmp:                    .res 2 ; Temporary storage
copy_source_addr:       .res 2 ; Source address for copying data to PPU
copy_dest_addr:         .res 2 ; Destination address for copying data to PPU or Memory
timeFrame:              .res 2 ; Frame timing counter
seed:                   .res 2 ; Zero Page Storage (Initialize seed to non-zero)

.segment "BSS"
palette_cache:          .res 32 ; temporary memory for palette, for dimming
palette_orig:           .res 32 ; clean, original palette values of your map/level

;-------------------------------------------------------------------------------
; Sprite OAM Data area - copied to VRAM in NMI routine
;-------------------------------------------------------------------------------
.segment "OAM"
oam:                    .res 256 ; sprite OAM data

;-------------------------------------------------------------------------------
;  non-volatile PRG-RAM
;-------------------------------------------------------------------------------
.segment "SRAM"
sram_signature:         .res 8
sram_last_started_game: .res 2
sram_last_started_line: .res 2
sram_last_started_save: .res 1

;-------------------------------------------------------------------------------
; Main Game Code
;-------------------------------------------------------------------------------
.segment "CODE"
; Include NES Function Library
.include "lib/ppu.s"
;-------------------------------------------------------------------------------
; Include files
;-------------------------------------------------------------------------------
; Routines to be executed from RAM must be loaded into RAM first, and then called via JSR
ram_routines:
.include "memory/Banking.s"
.include "memory/Flash.s"
.include "memory/Loader.s"

; Include various state controllers that manage different parts of the
; game logic and state.

.include "device/Joypad.s"
.include "device/Console.s"
.include "device/Buildinfo.s"

.include "graphic/Screen.s"
.include "graphic/Sprites.s"
.include "graphic/Tests.s"
.include "graphic/Text.s"

.include "memory/CopyToRam.s"
.include "memory/Saves.s"
.include "memory/Preloader.s"

.include "sound/Sounds.s"

;-------------------------------------------------------------------------------
; Core reset method for the game, this is called on powerup and when the system
; is reset. It is responsible for getting the system into a consistent state
; so that game logic will have the same effect every time it is run anew.
;-------------------------------------------------------------------------------
reset:
  sei             ; Disable Maskable Interrupts (IRQ) to prevent unwanted code execution during startup
  cld             ; Clear Decimal Mode flag (NES CPU doesn't support decimal math, but safe to clear)
  ldx #$FF        ; Load X register with $FF
  txs             ; Initialize Stack Pointer to point at memory location $01FF

  ; disable and reset sound
  jsr reset_sound

  ; --- First VBlank Wait: Allow PPU hardware to warm up and stabilize ---
  inx             ; Increment X from $FF to $00
  stx PPU_CTRL    ; Disable Non-Maskable Interrupts (NMI) by putting 0 into PPUCTRL
  stx PPU_MASK    ; Turn off PPU screen rendering (hide sprites and background)

@vblank_wait1:
  bit PPU_STATUS    ; Read PPU Status flags into CPU memory bit locations
  bpl @vblank_wait1 ; Loop back if bit 7 (VBlank flag) is clear. Continues when VBlank sets.

  ; --- Clear Internal System RAM ($0000-$07FF) ---
  ; Clears zero page, stack space, variable spaces, and resets the OAM buffer to safe positions.
  txa             ; Transfer X ($00) to A. A is now 0.
@clear_ram:
  sta $0000, x    ; Zero out Zero Page addresses ($0000-$00FF)
  sta $0100, x    ; Zero out Stack page RAM space ($0100-$01FF)
  sta $0300, x    ; Zero out custom RAM storage page ($0300-$03FF)
  sta $0400, x    ; Zero out custom RAM storage page ($0400-$04FF)
  sta $0500, x    ; Zero out custom RAM storage page ($0500-$05FF)
  sta $0600, x    ; Zero out custom RAM storage page ($0600-$06FF)
  sta $0700, x    ; Zero out custom RAM storage page ($0700-$07FF)
    
  lda #$FE        ; Load $FE value. Writing $00 to Y-coordinates puts sprites at top screen edge.
  sta $0200, x    ; Fill OAM sprite cache page ($0200-$02FF) with $FE to hide all sprites safely off-screen.
  lda #$00        ; Restore A register back to $00 value for the next loop block execution.
  inx             ; Increment X index by 1
  bne @clear_ram  ; If X rolled over back to $00, loop completes. Otherwise, clear next byte.

  ; Reset all OAM to EF
  lda #$00
  sta OAM_ADDR
  lda #$02
  sta OAM_DMA

  ; --- Second VBlank Wait: PPU is now fully ready for graphic instructions ---
@vblank_wait2:
  bit PPU_STATUS    ; Read PPU Status flags again
  bpl @vblank_wait2 ; Wait until PPU marks second full VBlank cycle, indicating complete system readiness.

  ; Reset Palettes
  bit PPU_STATUS
  lda #$3F
  sta PPU_ADDR
  lda #$00
  sta PPU_ADDR
  lda #$0F
  ldx #$20
@resetPalettesLoop:
  sta PPU_DATA
  dex
  bne @resetPalettesLoop

  ; --- Reset PPU Internal Scroll Coordinates ---
  lda #0           ; Load Accumulator with 0
  sta PPU_SCROLL   ; Send 0 to specify X coordinate camera scrolling offset
  sta PPU_SCROLL   ; Send 0 to specify Y coordinate camera scrolling offset
  jmp main

;-------------------------------------------------------------------------------
; Initializes the game on reset before the main loop begins to run
;-------------------------------------------------------------------------------
init:
; ==============================================================================
; Initialize the main state controllers for the game, these are responsible for managing different
; aspects of the game logic and state, such as the screen, the music, the sound effects, and the input.
; ==============================================================================

  ; loading loader and other RAM routines to RAM, these are used for bank switching and loading data to PPU
  jsr Copy_All_Loader_To_Ram

  jsr banking_init                ; Initialize banking and other cart stuff
  jsr console_detect              ; Detect console type
  jsr load_base_chr               ; Load the base CHR data for the current screen

  jsr read_joypad1                ; read buttons
  jsr load_state                  ; loading saved cursor position and other data
  jsr save_all_saves              ; saving last started game to flash (if any)

  jsr sound_init

  lda #%00000100 
  cmp pressed
  bne @skip_build_info
  ; build and hardware info
  jmp show_build_info

@skip_build_info:
  ldx #.lobyte(GAMES_COUNT)
  dex
  bne @not_single_game
  ldx #.hibyte(GAMES_COUNT)
  bne @not_single_game
  stx selected_game
  stx selected_game + 1
  jmp start_game

@not_single_game:
.if SECRETS>=1
  lda #%11001000
  cmp pressed
  bne @not_hidden_rom_1
  lda #.lobyte(GAMES_COUNT)
  sta selected_game
  lda #.hibyte(GAMES_COUNT)
  sta selected_game + 1
  jmp start_game

@not_hidden_rom_1:
.endif
.if SECRETS>=2
  lda #%11000100
  cmp pressed
  bne @not_hidden_rom_2
  lda #.lobyte(GAMES_COUNT)
  clc
  adc #1
  sta selected_game
  lda #.hibyte(GAMES_COUNT)
  adc #0
  sta selected_game + 1
  jmp start_game
  
@not_hidden_rom_2:
.endif
  lda #%11100000
  cmp pressed
  bne @not_tests
  jmp do_tests
@not_tests:

  jsr screen_init ; Initialize screen state and load the first screen
  jsr play_gull1_init
  jsr play_gull2_init
  jsr set_cursor_init
  jsr random_init

  ;*********************************************************
  ; Play a music track
  ; a = number of the music track to play
  ;*********************************************************
  lda #0 
  jsr famistudio_music_play

  ; Enable rendering and NMI
  EnableNMI ; enable NMI ,Background pattern table address $0000, Sprite pattern table address for 8x8 sprites $1000
  EnableRendering ; turn background on, turn objects on
  rts

;-------------------------------------------------------------------------------
; The main routine for the program. This sets up and handles the execution of
; the game loop and controls memory flags_render that indicate to the rendering loop
; if the game logic has finished processing.
;
; For the most part if you're emodifying or playing with the code, you shouldn't
; have to make edits here. Instead make changes to `init` and `main_loop`
; below...
;-------------------------------------------------------------------------------
main:
  jsr init
loop:
  jsr main_loop
  SetRenderFlag
@wait_for_render:
  bit nmi_ready_render
  bmi @wait_for_render
  jmp loop

;-------------------------------------------------------------------------------
; Main game loop logic that runs every tick
;-------------------------------------------------------------------------------
.proc main_loop
; 1. PROCESS THE NON-BLOCKING PALETTE STATE MACHINE
  jsr Update_Palette_Fade  

  ; 2. POLL THE DRAW TRIGGER (Fires automatically only after Fade Out completes)
  lda bg_request_draw
  beq @skip_bg_drawing     ; If 0, do nothing and skip background routines

  ;--------------------------------------------------------------------------------------------
  ; THIS SECTION EXECUTES EXACTLY ONCE ONCE THE SCREEN GOES COMPLETELY BLACK
  ;--------------------------------------------------------------------------------------------

  ; Step A: Disable PPU rendering (Recommended for a clean, glitch-free data write)
  VblankWait                      ; Wait for VBlank before touching PPU
  DisableRendering                ; Turn off Background and Sprite rendering during PPU write

  ; Step B: Render the new layout geometry to the Nametable
  jsr Draw_Background      ; Your custom routine to draw the new level / screen layout

  ; Step C: Load the target master colors for the new room/location
  lda screen
  jsr preload_palette ; Write the clean, target colors directly into palette_orig!!

  ; Step D: Instantly clear the draw trigger
  lda #0
  sta bg_request_draw      ; Reset the flag immediately so it won't re-fire next frame

  ; Step E: Re-enable PPU rendering hardware
  VblankWait               ; Wait for VBlank before touching PPU
  EnableRendering          ; Turn Background and Sprite rendering back on

  ; Step F: TRIGGER THE FADE IN TRANSITION
  lda #1                   ; Set Mode: 1 = BG + Sprites (or #0 for BG only)
  jsr Start_FadeIn         ; The screen will now smoothly reveal itself from pure black

  ;--------------------------------------------------------------------------------------------

@skip_bg_drawing:
  ; 3. STANDARD CORE GAMEPLAY ENGINE (Runs unhindered at 60 FPS)
  jsr joypad_update            ; Update joypad state
  jsr gull1_update             ; Update gull1 state
  jsr gull2_update             ; Update gull2 state
  jsr cursor_update            ; Update cursor state
  jsr bonfire_update           ; Update bonfire state
  jsr star_update              ; Update star state
  jsr Update_Screen            ; Updare screen in one frame
  rts

.endproc

;-------------------------------------------------------------------------------
; Non-maskable Interrupt Handler. This interrupt is executed at the end of each
; PPU rendering frame during the Vertical Blanking Interval (VBLANK). This
; interval lasts rougly 2273 CPU cycles, and to avoid graphical glitches all
; drawing in the "rendering_loop" should be completed within that timeframe.
;-------------------------------------------------------------------------------
.proc nmi
  pha ; save current register values
  tya
  pha
  txa
  pha
;-------------------------------------------------------------------------------
; Rendering loop logic that runs during the NMI
;-------------------------------------------------------------------------------
  bit nmi_ready_render
  bpl @skip_render
  ; Transfer Sprites via OAM
  lda #$00
  sta OAM_ADDR
  lda #.hibyte(oam)
  sta OAM_DMA
  UnsetRenderFlag
@skip_render:

;-------------------------------------------------------------------------------
; Palettes loop logic that runs during the NMI
;-------------------------------------------------------------------------------
  bit nmi_ready_palettes
  bpl @skip_palette       ; If data is not flagged as ready, skip PPU updates

  ; Initialize PPU target address to Palette RAM ($3F00)
  lda PPU_STATUS               ; Reset PPU address latch latch trigger
  lda #$3F
  sta PPU_ADDR
  lda #$00
  sta PPU_ADDR

  ldx #0
  lda fade_mode
  beq @write_bg_only      ; If 0, only upload Background colors (16 bytes)

@write_all:                 ; Option 2: Upload all 32 bytes (BG + Sprites)
  lda palette_cache, x
  sta PPU_DATA
  inx
  cpx #32
  bne @write_all
  jmp @done_palette

@write_bg_only:            ; Option 1: Upload 16 bytes (BG only)
  lda palette_cache, x
  sta PPU_DATA
  inx
  cpx #16
  bne @write_bg_only
  
@done_palette:
  UnsetPalettesFlag           ; Clear readiness flag, NMI task is complete
@skip_palette:
  ; ... rest of your NMI code goes here (OAM DMA sprite updates, scrolling, etc.) ...

;-------------------------------------------------------------------------------
; Calculation of frame timing.
;-------------------------------------------------------------------------------
  inc timeFrame
  bne @end_timing
  inc timeFrame + 1
@end_timing:

  ; Writes header
  jsr write_header_to_ppu

;-------------------------------------------------------------------------------
; Reset the VRAM address
;-------------------------------------------------------------------------------
  VramReset

;-------------------------------------------------------------------------------
; update FamiTone state, should be called every NMI
; in: none
;-------------------------------------------------------------------------------
  jsr famistudio_update

  pla ; restore register values
  tax
  pla
  tay
  pla
  rti
.endproc

;-------------------------------------------------------------------------------
; Character (Pattern) Data for the game. To edit the graphics, open
; the `src/binary/CHR-ROM.bin` file in YY-CHR.
; To get the file displaying correctly use the "2BPP NES" format.
;
; The first table contains the 8x8 sprites for the game, to make it easier to
; edit them use the "FC/NES x8" pattern option. The second table consists of
; mostly background tiles, so using the "Normal" pattern option is best.
;-------------------------------------------------------------------------------
.segment "BANK1"
;-------------------------------------------------------------------------------
.segment "BANK2"
;-------------------------------------------------------------------------------
.segment "BANK3"
;-------------------------------------------------------------------------------
.segment "BANK4"
;-------------------------------------------------------------------------------
.segment "BANK5"
;-------------------------------------------------------------------------------
; Load patterns sprites into the PRG ROM
;-------------------------------------------------------------------------------
chr_data:
.incbin "binary/tileset.chr" 

symbols:
.incbin "binary/menu_symbols.bin"
;-------------------------------------------------------------------------------
; Load palettes screens into the PRG ROM
;-------------------------------------------------------------------------------
pscreen_01:
.incbin "binary/palettes_screen_01.pal"
pscreen_02:
.incbin "binary/palettes_screen_02.pal"
pscreen_03:
.incbin "binary/palettes_screen_03.pal"
pscreen_04:
.incbin "binary/palettes_screen_04.pal"
pscreen_05:
.incbin "binary/palettes_screen_05.pal"
pscreen_06:
.incbin "binary/palettes_screen_06.pal"
pscreen_07:
.incbin "binary/palettes_screen_07.pal"
pscreen_08:
.incbin "binary/palettes_screen_08.pal"
pscreen_09:
.incbin "binary/palettes_screen_09.pal"
pscreen_10:
.incbin "binary/palettes_screen_10.pal"
pscreen_11:
.incbin "binary/palettes_screen_11.pal"
pscreen_12:
.incbin "binary/palettes_screen_12.pal"
pscreen_13:
.incbin "binary/palettes_screen_13.pal"
pscreen_14:
.incbin "binary/palettes_screen_14.pal"
pscreen_15:
.incbin "binary/palettes_screen_15.pal"
pscreen_16:
.incbin "binary/palettes_screen_16.pal"

;-------------------------------------------------------------------------------
; Load nametable screens and palette screens into the PRG ROM
;-------------------------------------------------------------------------------
.segment "BANK6"
; First 8kb of the CHR ROM are used for patterns
nscreen_01:
.incbin "binary/nametable_screen_01.nam"
nscreen_02:
.incbin "binary/nametable_screen_02.nam"
nscreen_03:
.incbin "binary/nametable_screen_03.nam"
nscreen_04:
.incbin "binary/nametable_screen_04.nam"
nscreen_05:
.incbin "binary/nametable_screen_05.nam"
nscreen_06:
.incbin "binary/nametable_screen_06.nam"
nscreen_07:
.incbin "binary/nametable_screen_07.nam"
nscreen_08:
.incbin "binary/nametable_screen_08.nam"

;Second 8kb of the CHR ROM are used for patterns
nscreen_09:
.incbin "binary/nametable_screen_09.nam"
nscreen_10:
.incbin "binary/nametable_screen_10.nam"
nscreen_11:
.incbin "binary/nametable_screen_11.nam"
nscreen_12:
.incbin "binary/nametable_screen_12.nam"
nscreen_13:
.incbin "binary/nametable_screen_13.nam"
nscreen_14:
.incbin "binary/nametable_screen_14.nam"
nscreen_15:
.incbin "binary/nametable_screen_15.nam"
nscreen_16:
.incbin "binary/nametable_screen_16.nam"