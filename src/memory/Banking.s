; ============================================================
; NES Cartridge Banking & Configuration Module
; ------------------------------------------------------------
; This module manages:
;   • PRG superbank (32 KB high-level bank selector)
;   • PRG bank (16 KB bank at $8000–$BFFF)
;   • CHR bank (8 KB CHR bank)
;   • PRG‑RAM bank (8 KB FRAM/WRAM bank)
;   • Cartridge configuration flags (mirroring, RAM enable, CHR write, flash write)
;
; It provides:
;   • Initialization routine (banking_init)
;   • Macros for selecting PRG/CHR/RAM banks
;   • Macros for enabling/disabling RAM, CHR writes, flash writes, 4‑screen mode
;   • sync_banks: writes all bank registers to mapper hardware
;
; Designed for discrete mappers using $5000–$5007 register range.
; ============================================================
.segment "ZEROPAGE"
; ------------------------------
; Variables
; ------------------------------
prg_superbank:   .res 2    ; 32 KB PRG superbank (two bytes)
prg_bank:        .res 1    ; 16 KB PRG bank at $8000
chr_bank:        .res 1    ; 8 KB CHR bank
prg_ram_bank:    .res 1    ; 8 KB PRG‑RAM bank
cart_config:     .res 1    ; last written configuration bits
banks_tmp:       .res 1    ; temporary storage for bank bit assembly

; ------------------------------
; Constants
; ------------------------------
prg_ram_banks = 4        ; number of PRG‑RAM banks available

.segment "RAM_ROUTINES"
; ============================================================
; banking_init
; ------------------------------------------------------------
; Initializes all banking registers:
;   • Sets all banks to 0
;   • Disables PRG‑RAM, CHR writes, flash writes
;   • Sets default mirroring mode
;   • Writes configuration to mapper
; ============================================================
.proc banking_init
  lda #0
  sta prg_superbank
  sta prg_superbank + 1
  sta prg_bank
  sta chr_bank
  sta prg_ram_bank
  jsr sync_banks

  ; Set mirroring mode (bit 3 = 1)
  lda #%00001000
  sta cart_config
  sta $5007               ; Write config to mapper
  rts
.endproc

; ============================================================
; Macros for selecting banks
; ============================================================

; Select 16 KB PRG bank at $8000–$BFFF
  .macro select_prg_bank
    sta prg_bank
    jsr sync_banks
  .endmacro

; Select 8 KB CHR bank
  .macro select_chr_bank
    sta chr_bank
    jsr sync_banks
  .endmacro

; Select 8 KB PRG‑RAM bank
  .macro select_prg_ram_bank
    sta prg_ram_bank
    jsr sync_banks
  .endmacro

; ============================================================
; sync_banks
; ------------------------------------------------------------
; Writes all bank registers to mapper hardware:
;   • $5000 / $5001 — PRG superbank
;   • $5003 — CHR bank (lower 5 bits)
;   • $5005 — combined PRG, CHR high bit, PRG‑RAM bank
;
; Also updates UNROM compatibility table.
; ============================================================
.proc sync_banks
  pha

  ; Write PRG superbank (two bytes)
  lda prg_superbank
  sta $5001
  lda prg_superbank + 1
  sta $5000

  ; Write CHR bank (lower 5 bits)
  lda chr_bank
  pha
  and #%00011111
  sta $5003

  ; Extract CHR bank high bit (bit 7)
  pla
  asl A
  asl A
  and #%10000000
  sta banks_tmp

  ; Insert PRG bank bits (shifted)
  lda prg_bank
  asl A
  asl A
  and #%01111100
  ora banks_tmp
  sta banks_tmp

  ; Insert PRG‑RAM bank (lower 2 bits)
  lda prg_ram_bank
  and #%00000011
  ora banks_tmp
  sta $5005

  ; UNROM compatibility update
  txa
  pha
  lda prg_bank
  tax
  sta unrom_bank_data, x
  pla
  tax

  pla
  rts
.endproc

; ============================================================
; Configuration Macros
; ------------------------------------------------------------
; These modify cart_config and write it to $5007.
; Bits:
;   bit 0 — PRG‑RAM enable
;   bit 1 — CHR write enable
;   bit 2 — Flash write enable
;   bit 5 — Four‑screen mode
; ============================================================

  .macro enable_prg_ram
    lda cart_config
    ora #%00000001
    sta cart_config
    sta $5007
  .endmacro

  .macro disable_prg_ram
    lda cart_config
    and #%11111110
    sta cart_config
    sta $5007
  .endmacro

  .macro enable_chr_write
    lda cart_config
    ora #%00000010
    sta cart_config
    sta $5007
  .endmacro

  .macro disable_chr_write
    lda cart_config
    and #%11111101
    sta cart_config
    sta $5007
  .endmacro

  .macro enable_flash_write
    lda cart_config
    ora #%00000100
    sta cart_config
    sta $5007
  .endmacro

  .macro disable_flash_write
    lda cart_config
    and #%11111011
    sta cart_config
    sta $5007
  .endmacro

  .macro enable_four_screen
    lda cart_config
    ora #%00100000
    sta cart_config
    sta $5007
  .endmacro

  .macro disable_four_screen
    lda cart_config
    and #%11011111
    sta cart_config
    sta $5007
  .endmacro