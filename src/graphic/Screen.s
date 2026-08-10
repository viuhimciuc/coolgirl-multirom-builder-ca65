; ==============================================================================
; Screen State (Movement, Draw, Dimming etc.)
; ==============================================================================
.segment "ZEROPAGE"
; Holds major flags render for the game. Bit 7 indicates to the NMI handler that
; state update are complete and the VRAM can be updated. Bits 0-6 are unused.
nmi_ready_render:      .res 1       ; Synchronization flag: 1 = NMI is allowed to update PPU render sprites
nmi_ready_palettes:    .res 1       ; Synchronization flag: 1 = NMI is allowed to update PPU for palettes
screen:                .res 1       ; Current screen number

.segment "RODATA"
  ; Data Addresses for nametable screens and palettes screens
addr_nametale:
  .addr nscreen_01, nscreen_02, nscreen_03, nscreen_04
  .addr nscreen_05, nscreen_06, nscreen_07, nscreen_08
  .addr nscreen_09, nscreen_10, nscreen_11, nscreen_12
  .addr nscreen_13, nscreen_14, nscreen_15, nscreen_16  

  ; Data Addresses for palettes screens
addr_palettes:
  .addr pscreen_01, pscreen_02, pscreen_03, pscreen_04
  .addr pscreen_05, pscreen_06, pscreen_07, pscreen_08
  .addr pscreen_09, pscreen_10, pscreen_11, pscreen_12
  .addr pscreen_13, pscreen_14, pscreen_15, pscreen_16

; Bit flags:
; bit 0 = bonfire (1 = on)
; bit 1 = stars   (1 = on)
EffectFlags:
  .byte %00  ; Scene 0
  .byte %00  ; Scene 1
  .byte %00  ; Scene 2
  .byte %00  ; Scene 3
  .byte %00  ; Scene 4
  .byte %00  ; Scene 5
  .byte %00  ; Scene 6
  .byte %00  ; Scene 7
  .byte %00  ; Scene 8
  .byte %11  ; Scene 9  → bonfire off, stars on
  .byte %11  ; Scene 10 → bonfire on, stars on
  .byte %11  ; Scene 11 → bonfire on, stars on
  .byte %10  ; Scene 12 → bonfire off, stars on
  .byte %10  ; Scene 13
  .byte %10  ; Scene 14
  .byte %00  ; Scene 15 → stars off

.segment "CODE"
; ==============================================================================
; Processing subroutine Screen (Movement, Draw, Dimming etc.)
; ==============================================================================
MaxScenes = 16
 ; Macros to set/unset flags nmi_ready_render
.macro SetRenderFlag
  lda #%10000000
  ora nmi_ready_render
  sta nmi_ready_render
.endmacro

.macro UnsetRenderFlag
  lda #%01111111
  and nmi_ready_render
  sta nmi_ready_render
.endmacro

  ; Macros to set/unset flags nmi_ready_palettes
.macro SetPalettesFlag
  lda #%10000000
  ora nmi_ready_palettes
  sta nmi_ready_palettes
.endmacro

.macro UnsetPalettesFlag
  lda #%01111111
  and nmi_ready_palettes
  sta nmi_ready_palettes
.endmacro

.include "dim.inc"

; ==============================================================================
; SCREEN INITIALIZATION AND PALETTE LOADING
; ==============================================================================
.proc screen_init
  ClearScreenAll            ; Macro: Clear the nametable to black

  lda text_lines_target     ; Get current target line count
  beq @clear_screen_id      ; If exactly 0, force screen ID to 0
  
  lsr A                     ; Shift right 4 times to divide by 16
  lsr A                     ; (Converts line count to screen index)
  lsr A
  lsr A
  
  cmp #MaxScenes            ; Check if screen index is out of bounds (>= 16)
  bcc @set_screen_id        ; If valid (< 16), keep the calculated index

@clear_screen_id:
  lda #0                    ; Force screen ID to 0 due to 0 lines or overflow

@set_screen_id:
  sta screen                ; Update the active screen ID

  ; The current screen ID into Accumulator
  jsr preload_palette       ; Pre-load the palettes for this specific screen
  jsr load_background       ; Load background data using the same screen ID in A
  
  jsr print_page            ; Render the main page content
  jsr make_header_string    ; Prepare the text string for the header
  jsr write_header_to_ppu   ; Push the header string to the PPU nametable
  
  lda #1                    ; Setup Fade-In parameter: 1 = BG + Sprites (0 = BG only)
  jsr Start_FadeIn          ; Trigger the palette dimming/fade-in effect
  rts                       ; Return from subroutine
.endproc

; ==============================================================================
; SCREEN UPDATE LOGIC AND FADE-OUT TRIGGER WITH DUAL-FLAG CHECKING
; ==============================================================================
.proc Update_Screen
  lda fade_step            ; Load the first fade flag status
  ora fade_waiting_for_nmi ; Combine it with the NMI wait flag status
  beq @process_update       ; If both flags are 0, proceed with screen update
  rts                       ; If either flag is active (!= 0), exit early

@process_update:
  ; Calculate (text_lines_target + lines_per_screen)
  lda text_lines_target
  clc
  adc #lines_per_screen
  sta tmp                  ; Store low byte of the sum
  lda text_lines_target+1
  adc #0                    ; Add carry to high byte
  
  ; Compare high bytes
  cmp draw_game_name+1
  bne @do_update            ; If high bytes mismatch, trigger update
  
  ; Compare low bytes
  lda tmp
  cmp draw_game_name
  bne @do_update            ; If low bytes mismatch, trigger update
  rts                       ; If exact match, no update is needed; exit

@do_update:
  lda text_lines_target    ; Get current target line count
  beq @clear_screen_id      ; If exactly 0, force screen ID to 0
  
  lsr A                     ; Shift right 4 times to divide by 16
  lsr A                     ; (Converts line count to screen index)
  lsr A
  lsr A
  
  cmp #MaxScenes            ; Check if screen index is out of bounds (>= 16)
  bcc @set_screen_id        ; If valid (< 16), keep the calculated index

@clear_screen_id:
  lda #0                    ; Force screen ID to 0 due to 0 lines or overflow

@set_screen_id:
  sta screen               ; Update the active screen ID
  
  ; Reset 16-bit timeFrame counter to $0000 (A is 0 here from previous logic)
  sta timeFrame
  sta timeFrame + 1

  ; Trigger fade-out effect
  lda #1                    ; Input parameter: 1 = BG + Sprites (0 = BG only)
  jsr Start_FadeOut         ; Execute fade out routine
  rts                       ; Return from subroutine
.endproc

; ==============================================================================
;  Scene Background Rendering Routine
; ==============================================================================
;  Description:
;    Handles scene index wrapping, background loading, palette
;    initialization, and text printing for each scene. After the
;    background is drawn, the routine enables or disables special
;    visual effects (bonfire and star animations) depending on the
;    current scene. Finally, it applies a fade‑in transition to
;    smoothly blend the updated palette into the active frame.
;
;  Explanation:
;    1. Rendering is temporarily disabled to safely update PPU data.
;    2. The scene index is validated and wrapped if it goes below 0
;       or exceeds MaxScenes.
;    3. The correct palette and background are loaded for the scene.
;    4. Scene‑specific text is printed.
;    5. Rendering is re‑enabled after VBlank to avoid visual artifacts.
;    6. Bonfire and star effects are toggled based on scene number:
;         - Scenes 9, 12 → bonfire disabled
;         - Scenes 10, 11 → bonfire enabled
;         - Scenes 9–14 → stars enabled
;         - Scenes 0–8 and 15+ → stars disabled
;    7. A fade‑in effect is triggered to apply the new palette.
;
;    This routine is typically called whenever the scene changes or
;    when the background needs to be refreshed. It ensures consistent
;    visual state across transitions and prepares all effects for the
;    next frame.
; ==============================================================================

.proc Draw_Background
  ; Wrap screen index if out of range
  lda screen
  bpl @check_upper
  lda #MaxScenes - 1
  sta screen
  jmp @scene_ok

@check_upper:
  cmp #MaxScenes
  bne @scene_ok
  lda #0
  sta screen

@scene_ok:
  ; Load background for this scene
  jsr load_background
  jsr print_page
  jsr make_header_string   ; Update the header string based on the current cursor position

  ; Load effect flags for this scene
  lda screen
  tax
  lda EffectFlags, x

  ; Bit 0 → bonfire
  and #%01
  beq @bonfire_off
  jsr EnableBonfire
  jmp @check_stars
@bonfire_off:
  jsr DisableBonfire

@check_stars:
  ; Reload flags
  lda EffectFlags, x
  ; Bit 1 → stars
  and #%10
  beq @stars_off
  jsr EnableStar
  jmp @fade
@stars_off:
  jsr DisableStar

@fade:
  ; Fade in BG + sprites
  lda #1
  jsr Start_FadeIn

  rts
.endproc

; ==============================================================================
; loading CHR data for the current screen from ROM to CHR RAM
; ==============================================================================
.proc load_base_chr
  lda #<.BANK(chr_data)        ; Select the PRG bank containing symbol data
  select_prg_bank
  lda #.lobyte(chr_data)       ; Low byte of source address
  sta copy_source_addr
  lda #.hibyte(chr_data)       ; High byte of source address
  sta copy_source_addr + 1
  jsr load_chr
  jsr load_base_symbols           ; Load the base symbols for the current screen
  rts
.endproc

; ============================================================
;  load_base_symbols
;  Loads base symbol graphics into PPU memory starting at $0240.
;  Copies 1 KB (4 pages × 256 bytes) + 192 bytes from PRG-ROM
;  into CHR-RAM using indirect addressing.
; ============================================================

.proc load_base_symbols

  lda #<.BANK(symbols)        ; Select the PRG bank containing symbol data
  select_prg_bank

  lda #.lobyte(symbols)       ; Low byte of source address
  sta copy_source_addr
  lda #.hibyte(symbols)       ; High byte of source address
  sta copy_source_addr + 1

  enable_chr_write            ; Allow CHR-RAM writes
  Vram $0B30                  ; Set PPU address to $0240 (symbol destination)

  ldy #16                     ; Start second tailer copy from offset 16 in the source data
  ldx #04                     ; Copy 4 × 256-byte pages (1 KB total)

@loop1:
  lda (copy_source_addr), y   ; Load byte from PRG-ROM
  sta PPU_DATA                ; Write byte to PPU

  iny                         ; Increment Y index
  bne @loop1                  ; Loop until Y wraps to 0

  inc copy_source_addr + 1    ; Move to next 256-byte page
  dex                         ; Decrement page counter
  bne @loop1                  ; Repeat for all 4 pages

  ; Copy remaining 192 bytes
  ldy #$00
@loop2:
  lda (copy_source_addr), y   ; Load byte from PRG-ROM
  sta PPU_DATA                ; Write byte to PPU

  iny
  cpy #192                    ; Stop after 192 bytes
  bne @loop2

  disable_chr_write           ; Disable CHR-RAM writes
  rts
.endproc

; ==============================================================================
; Loading nametable background from addr nametable scene to PPU
; The scene number is loaded into register A.
; ==============================================================================
.proc load_background
  sta tmp
  asl A
  tax
  lda addr_nametale, x
  sta copy_source_addr
  inx
  lda addr_nametale, x
  sta copy_source_addr + 1
  lda #<.BANK(nscreen_01)   ; Select a memory bank.
  select_prg_bank
  Vram NAMETABLE_A
  ldy #$00
  ldx #$04
: lda (copy_source_addr), y
  sta PPU_DATA
  iny
  bne :-
  inc copy_source_addr + 1
  dex
  bne :-
  lda tmp
  rts
.endproc

; ==============================================================================
; Loading palette from addr palettes scene to PPU
; The scene number is loaded into register A.
; ==============================================================================
.proc load_palettes
  sta tmp
  asl A
  tax
  lda addr_palettes, x
  sta copy_source_addr
  inx
  lda addr_palettes, x
  sta copy_source_addr + 1
  lda #<.BANK(pscreen_01)     ; Select a memory bank.
  select_prg_bank
  Vram PALETTE
  ldy #0
: lda (copy_source_addr), y
  sta PPU_DATA
  iny
  cpy #$20
  bne :-
  lda tmp
  rts
.endproc

; ==============================================================================
; Loading from addr palettes scene into palette cache
; The scene number is loaded into register A.
; ==============================================================================
.proc preload_palette
  sta tmp
  asl A
  tax
  lda addr_palettes, x
  sta copy_source_addr
  inx
  lda addr_palettes, x
  sta copy_source_addr + 1
  lda #<.BANK(pscreen_01)    ; Select a memory bank.
  select_prg_bank
  ldy #0
: lda (copy_source_addr), y
  sta palette_orig, y
  iny
  cpy #$20
  bne :-
  lda tmp
  rts
.endproc

; ==============================================================================
; Reset palette cache to dimmest values
; ==============================================================================
.proc reset_Palettes
  lda #$0F
  ldy #0
@loop:
  sta palette_cache, y
  iny
  cpy #$20
  bne @loop
  rts
.endproc