; -----------------------------------------------------------------------------
; SUBROUTINE: console_detect
; DESCRIPTION: Measures the duration of the frame to differentiate between
;              NTSC, PAL, and Dendy consoles, then checks hardware revision.
; -----------------------------------------------------------------------------
.segment "ZEROPAGE"
console_type:                     .res 1 ; Variable: Holds the detected console type flags

.segment "CODE"
.proc console_detect
  VblankWait                           ; Wait for V-Blank to synchronize timing
  ldx #0                               ; Clear low-byte counter
  ldy #0                               ; Clear high-byte counter

@detect_loop:
  inx                                  ; Increment low-byte counter
  bne @check_ppu                       ; Skip high-byte if low-byte didn't roll over
  iny                                  ; Increment high-byte counter every 256 loops
@check_ppu:
  lda PPU_STATUS                       ; Check PPU status register (Bit 7 is V-Blank)
  bpl @detect_loop                     ; Keep counting if Bit 7 is still clear (0)

  cpy #$0A                             ; Compare counter with PAL threshold
  beq @is_pal                          ; Jump if it matches PAL signature
  bcs @check_dendy                     ; Jump to check Dendy if counter is larger ($0B+)

@is_ntsc:
  lda #$01                             ; Flag configuration for NTSC region ($08 or $09)
  bne @check_hardware_rev              ; Proceed to hardware verification

@is_pal:
  lda #$02                             ; Flag configuration for PAL region ($0A)
  bne @check_hardware_rev              ; Proceed to hardware verification

@check_dendy:
  cpy #$0B                             ; Compare counter with Dendy threshold
  bne @unknown_region                  ; Safe fallback if timing is completely out of bounds
  lda #$04                             ; Flag configuration for Dendy clone region ($0B)
  bne @check_hardware_rev

@unknown_region:
  lda #$00                             ; Clear flags if region is unidentifiable

@check_hardware_rev:
  ldx $5000                            ; Read hardware register $5000
  beq @console_detect_not_new_dendy    ; If register returns 0, skip modification
  ora #$08                             ; Set bit 3 to mark it as a "NEW" revision

@console_detect_not_new_dendy:
  sta console_type                    ; Save finalized flags to Zero Page variable
  rts
.endproc