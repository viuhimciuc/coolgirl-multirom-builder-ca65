; ============================================================
; NES Save System Module
; ------------------------------------------------------------
; This module handles:
;   • Displaying and hiding the “Saving… keep power on” warning
;   • Saving launcher state (last game, scroll position, save ID)
;   • Loading launcher state from SRAM
;   • Loading and saving battery‑backed game saves (flash memory)
;   • Managing grouped save slots and rewriting them into flash
;
; It supports:
;   • SRAM (PRG‑RAM) for launcher metadata
;   • Flash memory for game save data
;   • Multi‑bank save grouping and sector erase/write
; ============================================================
.segment "ZEROPAGE"
saves:                    .res 4   ; Temporary array for 4 save locations
last_started_save:        .res 1   ; ID of last used save slot
save_warned:              .res 1   ; Flag: saving warning currently displayed

.segment "CODE"
; ============================================================
; saving_warning_show
; ------------------------------------------------------------
; Shows “Saving… keep power on” message if not already shown.
; Prevents repeated redraws by checking save_warned flag.
; ============================================================
.proc saving_warning_show
  lda save_warned
  beq @continue
  rts

@continue:
  inc save_warned

  VblankWait

  ; Disable PPU rendering
  lda #%00000000
  sta PPU_CTRL
  sta PPU_MASK

  ; Draw warning screen
  ClearScreen NAMETABLE_A
  LoadNameTable NAMETABLE_A, $01
  LoadAttributes ATTR_A, $00

  lda #1
  jsr preload_palette

  lda #$21
  sta PPU_ADDR
  lda #$C0
  sta PPU_ADDR

  lda #.lobyte(string_saving)
  sta copy_source_addr
  lda #.hibyte(string_saving)
  sta copy_source_addr+1
  jsr print_text

  lda #1
  jsr Palette_FadeIn

  rts
.endproc

; ============================================================
; saving_warning_hide
; ------------------------------------------------------------
; Hides the saving warning screen and restores normal rendering.
; ============================================================
.proc saving_warning_hide
  lda save_warned
  bne @continue
  rts

@continue:
  lda #0
  sta save_warned

  EnableNMI
  VblankWait

  lda #1
  jsr Palette_FadeOut

  lda #%00000000
  sta PPU_CTRL
  sta PPU_MASK
  rts
.endproc

; ============================================================
; save_state
; ------------------------------------------------------------
; Saves launcher metadata into SRAM:
;   • Signature (“COOLSAVE”)
;   • Last started game index
;   • Last scroll position
;   • Last save ID
; ============================================================
.proc save_state
  enable_prg_ram

  lda #0
  select_prg_ram_bank

  ; Write signature
  ldx #0
@signature_loop:
  lda saves_signature, x
  sta sram_signature, x
  inx
  cpx #8
  bne @signature_loop

  ; Save selected game
  lda selected_game
  sta sram_last_started_game
  lda selected_game+1
  sta sram_last_started_game+1

  ; Save scroll position
  lda text_lines_target
  sta sram_last_started_line
  lda text_lines_target+1
  sta sram_last_started_line+1

  ; Save last save ID
  lda last_started_save
  sta sram_last_started_save

  disable_prg_ram
  rts
.endproc

; ============================================================
; load_state
; ------------------------------------------------------------
; Loads launcher metadata from SRAM if signature matches.
; Otherwise resets values.
; ============================================================
load_state:
  enable_prg_ram

  lda #0
  select_prg_ram_bank

  ; Verify signature
  ldx #0
@signature_loop:
  lda saves_signature, x
  cmp sram_signature, x
  bne @end
  inx
  cpx #8
  bne @signature_loop

  ; Load last started game
.if ENABLE_LAST_GAME_SAVING <> 0
  lda sram_last_started_game
  sta selected_game
  lda sram_last_started_game+1
  sta selected_game+1

  ; Check for invalid game index
  lda selected_game
  sec
  sbc #.lobyte(GAMES_COUNT)
  lda <selected_game+1
  sbc #.hibyte(GAMES_COUNT)
  bcs @ovf

  ; Load scroll position
  lda sram_last_started_line
  sta text_lines_target
  lda sram_last_started_line+1
  sta text_lines_target+1
.else
  lda #0
  sta selected_game
  sta selected_game+1
  sta text_lines_target
  sta text_lines_target+1
.endif

  ; Load last save ID
  lda sram_last_started_save
  sta last_started_save
  jmp @end

@ovf:
  ; Reset invalid values
  lda #0
  sta selected_game
  sta selected_game+1
  sta text_lines_target
  sta text_lines_target+1

@end:
  disable_prg_ram
  rts

; ============================================================
; load_save
; ------------------------------------------------------------
; Loads battery‑backed save from flash into PRG‑RAM.
; ============================================================
.proc load_save
  pha
  tya
  pha
  txa
  pha

  lda loader_game_save
  beq @done

  sta loader_game_save_superbank
  dec loader_game_save_superbank

  lda loader_game_save_bank
  select_prg_ram_bank

  lda #0
  sta copy_source_addr
  sta copy_dest_addr

  lda #$80
  sta copy_source_addr+1

  lda #$60
  sta copy_dest_addr+1

  enable_prg_ram
  jsr read_flash
  disable_prg_ram

@done:
  pla
  tax
  pla
  tay
  pla
  rts
.endproc

; ============================================================
; save_save
; ------------------------------------------------------------
; Saves battery‑backed save from PRG‑RAM into flash.
; ============================================================
.proc save_save
  pha
  tya
  pha
  txa
  pha

  lda loader_game_save
  beq @done

  sta loader_game_save_superbank
  dec loader_game_save_superbank

  lda loader_game_save_bank
  select_prg_ram_bank

  lda #0
  sta copy_source_addr
  sta copy_dest_addr

  lda #$60
  sta copy_source_addr+1

  lda #$80
  sta copy_dest_addr+1

  enable_prg_ram
  jsr write_flash
  disable_prg_ram

@done:
  pla
  tax
  pla
  tay
  pla
  rts
.endproc

; ============================================================
; save_all_saves
; ------------------------------------------------------------
; Saves all grouped save slots:
;   • Shows warning screen
;   • Loads three saves into RAM
;   • Calculates sector start
;   • Erases flash sector
;   • Writes four saves back to flash
;   • Hides warning screen
; ============================================================
.proc save_all_saves
  ldx last_started_save
  bne @there_is_save
  jmp @done

@there_is_save:
  jsr saving_warning_show

  ldx last_started_save
  dex
  txa
  and #%11111100
  ora #1
  sta loader_game_save

  lda #0
  sta loader_game_save_bank

  ; Load three saves
  ldx #3
@load_all_saves:
  lda loader_game_save
  cmp last_started_save
  bne @skip1
  inc loader_game_save
@skip1:

  lda loader_game_save_bank
  cmp #2
  bne @skip2
  inc loader_game_save_bank
@skip2:

  lda loader_game_save
  ldy loader_game_save_bank
  sta saves, y

  jsr load_save

  inc loader_game_save
  inc loader_game_save_bank

  dex
  bne @load_all_saves

  ; Second bank always contains last save
  ldx last_started_save
  txa
  ldy #2
  sta saves, y

  dex
  txa
  ora #%00000011
  sta loader_game_save_superbank

  lda #0
  select_prg_ram_bank

  jsr sector_erase

  ; Write four saves back
  ldy #0
@write:
  lda saves, y
  sta loader_game_save
  sty loader_game_save_bank
  jsr save_save

  iny
  cpy #4
  bne @write

  jsr saving_warning_hide

@done:
  lda #0
  sta last_started_save

  jsr save_state
  rts
.endproc

; ============================================================
; Signature for SRAM validation
; ============================================================
.segment "RODATA"
saves_signature:
  .byte 'C','O','O','L','S','A','V','E'