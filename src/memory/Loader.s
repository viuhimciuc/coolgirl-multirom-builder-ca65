; ============================================================
; NES Game Loader & CHR Streaming Module
; ------------------------------------------------------------
; This module handles:
;   • Initial mapper register setup for loading a game
;   • Memory cleanup before jumping to the loaded game
;   • Streaming CHR data from PRG ROM into CHR RAM
;   • Multi‑bank CHR loading (8 KB per bank)
;
; Used by the bootloader to prepare the cartridge state and
; transfer graphics data before executing the game entry point.
; ============================================================
.segment "ZEROPAGE"
loader_reg_0:                  .res 1
loader_reg_1:                  .res 1
loader_reg_2:                  .res 1
loader_reg_3:                  .res 1
loader_reg_4:                  .res 1
loader_reg_5:                  .res 1
loader_reg_6:                  .res 1
loader_reg_7:                  .res 1

loader_chr_start_h:            .res 1   ; PRG superbank high byte
loader_chr_start_l:            .res 1   ; PRG superbank low byte
loader_chr_start_s:            .res 1   ; PRG offset inside superbank
loader_chr_left:               .res 1   ; number of 8 KB CHR blocks left to load

loader_game_save:              .res 1
loader_game_save_bank:         .res 1
loader_game_save_superbank:    .res 1

.segment "RAM_ROUTINES"
; ============================================================
; loader
; ------------------------------------------------------------
; Writes all mapper registers from loader_reg_* variables,
; then jumps to the memory‑cleaning routine.
; ============================================================
loader:
  lda loader_reg_0
  sta $5000
  lda loader_reg_1
  sta $5001
  lda loader_reg_2
  sta $5002
  lda loader_reg_3
  sta $5003
  lda loader_reg_4
  sta $5004
  lda loader_reg_5
  sta $5005
  lda loader_reg_6
  sta $5006
  lda loader_reg_7
  sta $5007

  jmp loader_clean_and_start

; ============================================================
; load_all_chr_banks
; ------------------------------------------------------------
; Loads all CHR banks from PRG ROM into CHR RAM.
; Each iteration loads one 8 KB block.
;
; Variables:
;   loader_chr_left  — number of 8 KB blocks to load
;   loader_chr_start_l/h — initial PRG superbank
;   loader_chr_start_s   — initial PRG offset inside superbank
; ============================================================
.proc load_all_chr_banks
  lda #0
  sta chr_bank
  sta prg_bank
  sta copy_source_addr

  lda loader_chr_start_l
  sta prg_superbank
  lda loader_chr_start_h
  sta prg_superbank + 1

@loop:
  lda loader_chr_left
  beq @done
  dec loader_chr_left

  jsr sync_banks

  ; Set PRG source address high byte
  lda loader_chr_start_s
  sta copy_source_addr + 1

  ; Load 8 KB of CHR data
  jsr load_chr

  ; Advance PRG offset by $2000 (8 KB)
  lda loader_chr_start_s
  clc
  adc #$20
  sta loader_chr_start_s

  cmp #$C0
  bne @chr_s_not_inc

  ; Overflow → move to next PRG superbank
  lda #$80
  sta loader_chr_start_s

  lda prg_superbank
  clc
  adc #1
  sta prg_superbank

  lda prg_superbank + 1
  adc #0
  sta prg_superbank + 1

@chr_s_not_inc:
  inc chr_bank
  jmp @loop

@done:
  jsr banking_init
  rts
.endproc

; ============================================================
; load_chr
; ------------------------------------------------------------
; Loads a single 8 KB CHR block from PRG ROM into CHR RAM.
; Source: (copy_source_addr)
; Target: PPU $0000–$1FFF
; ============================================================
.proc load_chr
  enable_chr_write            ; Allow CHR-RAM writes

  Vram $0000                  ; Set PPU address to $0000

  ldy #$00
  ldx #$20                    ; 32 pages × 256 bytes = 8 KB

@loop:
  lda (copy_source_addr), y   ; Load byte from PRG-ROM
  sta PPU_DATA                ; Write byte to PPU

  iny                         ; Increment Y index
  bne @loop                   ; Loop until Y wraps to 0

  inc copy_source_addr + 1    ; Move to next 256-byte page
  dex                         ; Decrement page counter
  bne @loop                   ; Repeat for all 20 pages

  disable_chr_write           ; Disable CHR-RAM writes
  rts
.endproc

; SWITCH SEGMENT BEFORE THE CLEANUP ROUTINE:
; Redirects the following code to the specialized memory slot matching RAM address $07E0
.segment "LOADER_CLEAN"
; ============================================================
; loader_clean_and_start
; ------------------------------------------------------------
; Cleans RAM before starting the loaded game.
; Fills memory from $0200 up to the end of RAM with zeros.
; Then jumps to the game's reset vector at $FFFC.
; ============================================================
loader_clean_and_start:
  ; Clean internal RAM ($0000-$07FF) before starting the game
  lda #$00
  sta copy_source_addr       ; Initialize Zero Page pointer (low byte)
  sta copy_source_addr + 1   ; Initialize Zero Page pointer (high byte)
  ldy #$02                   ; Start wiping RAM from page index $02 ($0200)
  ldx #$07                   ; Loop counter for clearing 7 full pages of memory
@loop:
  sta (copy_source_addr), y  ; Indirect indexed write to clear RAM byte
  iny
  bne @loop                  ; Keep clearing bytes until the current page wraps around to 0
  inc copy_source_addr + 1   ; Move Zero Page pointer to the next memory page
  dex
  bne @loop                  ; Repeat until all targeted pages are cleared
@loop2:
  sta (copy_source_addr), y  ; Final pass: Wipes remaining bytes in page 7, including this loop code
  iny
  cpy #.lobyte(@loop2)       ; Check if Y index reached the low byte of this exact loop's address
  bne @loop2                 ; Stop loop just before erasing the final jump instruction

  jmp ($FFFC)                ; Indirect jump to the hardware Reset Vector to start the game