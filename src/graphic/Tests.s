; ============================================================
; NES PRG‑RAM & CHR‑RAM Diagnostic Test
; ------------------------------------------------------------
; This routine performs a full read/write verification of:
;   • PRG RAM (all banks, if present)
;   • CHR RAM (all banks, based on detected size)
;
; It writes pseudo‑random data, reads it back, compares results,
; and records failure flags. After testing, it prints results
; on screen using PPU text routines.
;
; All tests run continuously until both PRG and CHR RAM pass.
; ============================================================
.segment "ZEROPAGE"
test_rw:             .res 1    ; 0 = write phase, 1 = read phase
test_xor:            .res 1    ; XOR mask used to invert test pattern
test_prg_ram_failed: .res 1    ; PRG RAM failure flag
test_chr_ram_failed: .res 1    ; CHR RAM failure flag
test_bank:           .res 1    ; Current bank index for testing

.segment "CODE"
do_tests:
  ; Detect CHR RAM size (number of banks)
  jsr detect_chr_ram_size

  ; Detect presence of PRG RAM
  jsr prg_ram_detect

@do_tests_again:
  ; Invert XOR mask each iteration to vary test pattern
  lda test_xor
  eor #$FF
  sta test_xor

  VblankWait                 ; Wait for v‑blank before disabling PPU
  lda #%00000000             ; Disable PPU rendering
  sta PPU_CTRL
  sta PPU_MASK

  lda #$00
  sta test_rw               ; Start with write phase
  sta test_prg_ram_failed   ; Reset PRG RAM failure flag
  sta test_chr_ram_failed   ; Reset CHR RAM failure flag

  lda prg_ram_present
  beq @chr                   ; Skip PRG RAM test if not present

  enable_prg_ram             ; Enable PRG RAM access

; ------------------------------------------------------------
; PRG RAM TEST
; ------------------------------------------------------------
@prg_ram:
  jsr random_init            ; Initialize random generator

  lda #(prg_ram_banks-1)     ; Start from last PRG RAM bank
  sta test_bank

@prg_ram_test_loop_bank:
  lda #0
  jsr play_sfx_without_NMI   ; Play tick sound (no NMI)

  lda test_bank
  select_prg_ram_bank        ; Switch PRG RAM bank

  lda #$00
  sta copy_dest_addr
  lda #$60
  sta copy_dest_addr+1      ; Destination = $6000

  ldy #$00
  ldx #$20                   ; 32 pages of 256 bytes each

@prg_ram_test_loop:
  jsr random                 ; Generate next random byte

  lda test_rw               ; Write or read phase?
  bne @prg_ram_test_read

  ; ---------------- WRITE PHASE ----------------
  lda seed
  eor test_xor              ; Apply XOR mask
  sta (copy_dest_addr), y
  jmp @prg_ram_test_next

@prg_ram_test_read:
  ; ---------------- READ PHASE -----------------
  lda seed
  eor test_xor
  cmp (copy_dest_addr), y
  beq @prg_ram_test_next     ; OK

  lda #1
  sta test_prg_ram_failed    ; Mismatch → failure

@prg_ram_test_next:
  iny
  bne @prg_ram_test_loop

  inc copy_source_addr+1
  inc copy_dest_addr+1       ; Move to next page

  dex
  bne @prg_ram_test_loop

  dec test_bank
  bpl @prg_ram_test_loop_bank

  lda test_rw
  bne @chr                   ; If read phase done → go to CHR test

  inc test_rw               ; Switch to read phase
  jmp @prg_ram

; ------------------------------------------------------------
; CHR RAM TEST
; ------------------------------------------------------------
@chr:
  disable_prg_ram            ; Disable PRG RAM before CHR test

  lda #$00
  sta test_rw                ; Start with write phase

@chr_again:
  jsr random_init            ; Reset RNG

  lda #1
  ldx chr_ram_size           ; Number of CHR banks

  ; Compute (1 << chr_ram_size) - 1
@shift_loop:
  dex
  bmi @shift_done
  asl A
  jmp @shift_loop

@shift_done:
  sec
  sbc #1
  sta test_bank             ; Highest CHR bank index

  enable_chr_write           ; Allow CHR writes

@chr_test_loop_bank:
  lda #0
  jsr play_sfx_without_NMI

  lda test_bank
  select_chr_bank            ; Switch CHR bank

  lda #$00
  sta PPU_ADDR
  sta PPU_ADDR               ; Reset PPU address to $0000

  ldy #$00
  ldx #$20

  lda test_rw
  beq @chr_test_loop
  lda PPU_DATA               ; Dummy read required

@chr_test_loop:
  jsr random

  lda test_rw
  bne @chr_test_read

  ; ---------------- WRITE PHASE ----------------
  lda seed
  eor test_xor
  sta PPU_DATA
  jmp @chr_test_next

@chr_test_read:
  ; ---------------- READ PHASE -----------------
  lda seed
  eor test_xor
  cmp PPU_DATA
  beq @chr_test_next

  lda #1
  sta test_chr_ram_failed

@chr_test_next:
  iny
  bne @chr_test_loop

  dex
  bne @chr_test_loop

  dec test_bank
  bpl @chr_test_loop_bank

  lda test_rw
  bne @tests_end

  inc test_rw
  jmp @chr_again

; ------------------------------------------------------------
; DISPLAY TEST RESULTS
; ------------------------------------------------------------
@tests_end:
  jsr load_base_chr               ; Restore original layout tileset mapping
  ClearScreen NAMETABLE_A
  LoadNameTable NAMETABLE_A, $01
  LoadAttributes ATTR_A, $00
  lda #1
  jsr load_palettes

  ; ----- PRG RAM RESULT -----
  lda #$21
  sta PPU_ADDR
  lda #$A4
  sta PPU_ADDR

  lda #.lobyte(string_prg_ram_test)
  sta copy_source_addr
  lda #.hibyte(string_prg_ram_test)
  sta copy_source_addr+1
  jsr print_text

  lda prg_ram_present
  bne @prg_ram_test_result

  ; PRG RAM not available
  lda #.lobyte(string_not_available)
  sta copy_source_addr
  lda #.hibyte(string_not_available)
  sta copy_source_addr+1
  jmp @prg_ram_test_result_print

@prg_ram_test_result:
  ldx test_prg_ram_failed
  bne @prg_ram_test_result_fail

  ; PRG RAM OK
  lda #.lobyte(string_passed)
  sta copy_source_addr
  lda #.hibyte(string_passed)
  sta copy_source_addr+1
  jmp @prg_ram_test_result_print

@prg_ram_test_result_fail:
  ; PRG RAM failed
  lda #.lobyte(string_failed)
  sta copy_source_addr
  lda #.hibyte(string_failed)
  sta copy_source_addr+1

@prg_ram_test_result_print:
  jsr print_text

  ; ----- CHR RAM RESULT -----
  lda #$21
  sta PPU_ADDR
  lda #$E4
  sta PPU_ADDR

  lda #.lobyte(string_chr_ram_test)
  sta copy_source_addr
  lda #.hibyte(string_chr_ram_test)
  sta copy_source_addr+1
  jsr print_text

  lda chr_ram_size
  asl A
  tay
  lda chr_ram_sizes, y
  sta copy_source_addr
  lda chr_ram_sizes+1, y
  sta copy_source_addr+1
  jsr print_text

  lda #01                    ; put tile space
  sta PPU_DATA               ; Print space

  ldx test_chr_ram_failed
  bne @chr_test_result_fail

  lda #.lobyte(string_passed)
  sta copy_source_addr
  lda #.hibyte(string_passed)
  sta copy_source_addr+1
  jmp @chr_test_result_print

@chr_test_result_fail:
  lda #.lobyte(string_failed)
  sta copy_source_addr
  lda #.hibyte(string_failed)
  sta copy_source_addr+1

@chr_test_result_print:
  jsr print_text

  VramReset
  VblankWait
  lda #BG_ON|OBJ_OFF
  sta PPU_MASK

  ldx #$FF
@do_tests_wait:
  VblankWait
  dex
  bne @do_tests_wait

  lda #0
  ora test_prg_ram_failed
  ora test_chr_ram_failed
  beq @do_tests_ok

  lda #4
  jsr play_sfx_without_NMI

@do_tests_stop:
  jmp @do_tests_wait

@do_tests_ok:
  jmp @do_tests_again