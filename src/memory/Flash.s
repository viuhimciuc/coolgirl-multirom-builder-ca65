; ============================================================
; NES Flash Memory Support Routines
; ------------------------------------------------------------
; This module provides:
;   • Flash chip detection (CFI signature)
;   • Sector erase routine
;   • Flash write routine (byte‑programming loop)
;   • Flash read routine
;   • Superbank calculation for save‑file addressing
;
; Supports flash chips using the standard AMD/Spansion command set:
;   • Unlock sequence: AA @ 0x0AAA, 55 @ 0x0555
;   • CFI entry: 0x98 @ 0x0AAA
;   • Reset: 0xF0 @ 0x0000
;   • Sector erase: 0x80 / 0x30 sequence
;   • Byte program: 0xA0 sequence
;
; All routines assume mapper registers at $5000–$5007.
; ============================================================
.segment "ZEROPAGE"
flash_type:      .res 1      ; Flash memory size/type (read from CFI)

.segment "RAM_ROUTINES"
; ============================================================
; flash_detect
; ------------------------------------------------------------
; Detects flash memory by entering CFI mode and checking the
; "QRY" signature. If valid, reads flash size from offset $4E.
; ============================================================
.proc flash_detect
  lda #0
  sta flash_type

  enable_flash_write

  ; Reset flash
  lda #$F0
  sta $8000

  ; Enter CFI mode (0x98 → 0x0AAA)
  lda #$98
  sta $8AAA

  ; Check CFI signature "QRY"
  lda $8020
  cmp #'Q'
  bne @end

  lda $8022
  cmp #'R'
  bne @end

  lda $8024
  cmp #'Y'
  bne @end

  ; Read flash size/type
  lda $804E
  sta flash_type

@end:
  ; Exit CFI mode
  lda #$F0
  sta $8000

  disable_flash_write
  rts
.endproc

; ============================================================
; sector_erase
; ------------------------------------------------------------
; Erases a flash sector using the standard AMD erase sequence.
; Waits until the flash reports completion (data polling).
; ============================================================
.proc sector_erase
  enable_flash_write
  jsr flash_set_superbank

  ; Reset
  lda #$F0
  sta $8000

  ; Unlock sequence
  lda #$AA
  sta $8AAA
  lda #$55
  sta $8555

  ; Erase command
  lda #$80
  sta $8AAA

  ; Unlock again
  lda #$AA
  sta $8AAA
  lda #$55
  sta $8555

  ; Sector erase (0x30 → 0x0000)
  lda #$30
  sta $8000

  disable_flash_write

  ; Poll until flash reports completion
  lda #$FF
@wait:
  cmp $8000
  bne @wait
  cmp $8000
  bne @wait

  jsr banking_init
  rts
.endproc

; ============================================================
; write_flash
; ------------------------------------------------------------
; Writes a full 8 KB block to flash using byte‑programming.
; Uses the AMD/Spansion A0 command sequence.
; Performs data polling after each byte.
; ============================================================
.proc write_flash
  enable_flash_write
  jsr flash_set_superbank

  ldy #$00
  ldx #$20              ; 32 pages of 256 bytes

@loop:
  ; Reset
  lda #$F0
  sta $8000

  ; Unlock sequence
  lda #$AA
  sta $8AAA
  lda #$55
  sta $8555

  ; Byte‑program command
  lda #$A0
  sta $8AAA

  ; Write byte
  lda (copy_source_addr), y
  sta (copy_dest_addr), y

@wait:
  cmp (copy_dest_addr), y
  bne @wait
  cmp (copy_dest_addr), y
  bne @wait

  iny
  bne @loop

  inc copy_source_addr+1
  inc copy_dest_addr+1

  dex
  bne @loop

  disable_flash_write
  jsr banking_init
  rts
.endproc

; ============================================================
; read_flash
; ------------------------------------------------------------
; Reads a full 8 KB block from flash into RAM.
; ============================================================
.proc read_flash
  jsr flash_set_superbank

  ldy #0
  ldx #$20

@loop:
  lda (copy_source_addr), y
  sta (copy_dest_addr), y

  iny
  bne @loop

  inc copy_source_addr+1
  inc copy_dest_addr+1

  dex
  bne @loop

  jsr banking_init
  rts
.endproc

; ============================================================
; flash_set_superbank
; ------------------------------------------------------------
; Calculates PRG superbank based on save‑file ID.
; loader_game_save_superbank contains the number of sectors
; to skip. Each sector corresponds to 2 PRG superbank units.
; ============================================================
.proc flash_set_superbank
  lda #0
  sta prg_bank

  ldx loader_game_save_superbank
  inx                     ; +1 sector

  lda #$00
  sta prg_superbank
  sta prg_superbank+1

@loop:
  ; Subtract 2 from 16‑bit superbank value
  sec
  lda prg_superbank
  sbc #$02
  sta prg_superbank

  lda prg_superbank+1
  sbc #0
  sta prg_superbank+1

  dex
  bne @loop

  jsr sync_banks
  rts
.endproc