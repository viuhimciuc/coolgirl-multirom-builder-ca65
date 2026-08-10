; =============================================================================
; NES SYSTEM INFORMATION AND BUILD INFO DISPLAY MODULE
; =============================================================================
.segment "ZEROPAGE"
prg_ram_present:              .res 1 ; Flag: 1 if PRG RAM is detected, 0 if not
chr_ram_size:                 .res 1 ; CHR RAM size 8*2^xKB

; -----------------------------------------------------------------------------
; SUBROUTINE: show_build_info
; DESCRIPTION: Detects hardware specs, clears screen, and prints system info.
; -----------------------------------------------------------------------------
.segment "CODE"
show_build_info:
  jsr flash_detect                ; Detect the installed flash memory type
  jsr detect_chr_ram_size         ; Detect the size of CHR RAM
  jsr prg_ram_detect              ; Check if PRG RAM is physically present

  ClearScreen NAMETABLE_A         ; Wipe the nametable for fresh rendering
  LoadNameTable NAMETABLE_A, $01
  LoadAttributes ATTR_A, $00      ; Load text attributes
  lda #1                          ; Select palette number
  jsr preload_palette             ; Load palettes from the second screen.

print_version:
  lda #$20                        ; Push PPU High Byte directly to target register
  sta PPU_ADDR
  ldx #$E4                        ; Pass PPU Low Byte via X
  ldy #.lobyte(string_version)    ; Pass String Pointer Low via Y
  lda #.hibyte(string_version)    ; Pass String Pointer High via A
  jsr set_ppu_and_text            ; Draw version string

print_commit:
  lda #$21
  sta PPU_ADDR
  ldx #$24
  ldy #.lobyte(string_commit)
  lda #.hibyte(string_commit)
  jsr set_ppu_and_text            ; Draw git commit hash string

print_filename:
  bit PPU_STATUS                  ; Reset PPU address latch toggles
  lda #$21
  sta PPU_ADDR
  ldx #$64
  ldy #.lobyte(string_file)
  lda #.hibyte(string_file)
  jsr set_ppu_and_text            ; Draw active filename string

print_build_date:
  lda #$21
  sta PPU_ADDR
  ldx #$A4
  ldy #.lobyte(string_build_date)
  lda #.hibyte(string_build_date)
  jsr set_ppu_and_text            ; Draw build date stamp

print_build_time:
  lda #$21
  sta PPU_ADDR
  ldx #$E4
  ldy #.lobyte(string_build_time)
  lda #.hibyte(string_build_time)
  jsr set_ppu_and_text            ; Draw build time stamp

print_console_regions:
  lda #$22
  sta PPU_ADDR
  ldx #$24
  ldy #.lobyte(string_console_type)
  lda #.hibyte(string_console_type)
  jsr set_ppu_and_text            ; Draw "Console Type:" label

  lda console_type
  and #$08                        ; Check bit 3 for "NEW" console revision
  beq @no_new
  lda #.lobyte(string_new)
  ldx #.hibyte(string_new)
  jsr print_string_direct
@no_new:

  lda console_type
  and #$01                        ; Check bit 0 for NTSC region
  beq @no_ntsc
  lda #.lobyte(string_ntsc)       ; Fixed fallback or standard print target alignment
  ldx #.hibyte(string_ntsc)
  jsr print_string_direct
@no_ntsc:

  lda console_type
  and #$02                        ; Check bit 1 for PAL region
  beq @no_pal
  lda #.lobyte(string_pal)
  ldx #.hibyte(string_pal)
  jsr print_string_direct
@no_pal:

  lda console_type
  and #$04                        ; Check bit 2 for Dendy region clone
  beq @no_dendy
  lda #.lobyte(string_dendy)
  ldx #.hibyte(string_dendy)
  jsr print_string_direct
@no_dendy:

print_flash_type:
  lda #$22
  sta PPU_ADDR
  ldx #$64
  ldy #.lobyte(string_flash)
  lda #.hibyte(string_flash)
  jsr set_ppu_and_text            ; Draw "Flash:" hardware label

  lda flash_type
  bne @writable                   ; If type != 0, it is writable flash
  lda #.lobyte(string_read_only)
  ldx #.hibyte(string_read_only)
  jsr print_string_direct         ; Draw "Read-Only" string
  jmp print_chr_size              ; Skip sizes and go to CHR section

@writable:
  lda #.lobyte(string_writable)
  ldx #.hibyte(string_writable)
  jsr print_string_direct         ; Draw "Writable" status string
  lda #01                         ; Put tile space
  sta PPU_DATA

  lda flash_type                  ; Calculate offset index for flash size table
  sec
  sbc #20                         ; Normalize table offset
  asl A                           ; Multiply by 2 (pointers are 2 bytes)
  tay
  lda flash_sizes, y
  ldx flash_sizes+1, y
  jsr print_string_direct
  
print_chr_size:
  lda #$22
  sta PPU_ADDR
  ldx #$A4
  ldy #.lobyte(string_chr_ram)
  lda #.hibyte(string_chr_ram)
  jsr set_ppu_and_text            ; Draw "CHR RAM:" label

  lda chr_ram_size
  asl A                           ; Multiply by 2 for word pointer array
  tay
  lda chr_ram_sizes, y
  ldx chr_ram_sizes+1, y
  jsr print_string_direct

print_prg_ram:
  lda #$22
  sta PPU_ADDR
  ldx #$E4
  ldy #.lobyte(string_prg_ram)
  lda #.hibyte(string_prg_ram)
  jsr set_ppu_and_text            ; Draw "PRG RAM:" label

  lda prg_ram_present
  beq @not_present
  lda #.lobyte(string_present)
  ldx #.hibyte(string_present)
  bne @render_prg_status          ; Safe structural branch
@not_present:
  lda #.lobyte(string_not_available)
  ldx #.hibyte(string_not_available)
@render_prg_status:
  jsr print_string_direct

enable_display:
  lda #1
  jsr Palette_FadeIn                ; Smooth screen fade-in effect

show_build_info_infin:
  jsr read_joypad1
  lda pressed
  and #%11000000                    ; Check if A or B button is pressed
  beq show_build_info_infin         ; Keep looping if no input detected

  lda #1
  jsr Palette_FadeOut               ; Fade out display before exit

  jmp reset                         ; Return to engine master execution loop

; -----------------------------------------------------------------------------
; SUBROUTINE: prg_ram_detect
; DESCRIPTION: Tests save-RAM storage viability by writing/reading test bytes.
; -----------------------------------------------------------------------------
.proc prg_ram_detect
  enable_prg_ram                  ; Open memory mapping gate to $7000-$7FFF
  
  lda #$AA                        ; Test pattern 1
  sta $7000
  cmp $7000
  bne @failed
  
  lda #$55                        ; Test pattern 2
  sta $7000
  cmp $7000
  beq @success

@failed:
  lda #0                          ; Mark RAM as missing/broken
  sta prg_ram_present
  beq @clean_exit

@success:
  lda #1                          ; Mark RAM as active and verified
  sta prg_ram_present

@clean_exit:
  disable_prg_ram                 ; Lock write gates to prevent corruption
  rts
.endproc

; =============================================================================
; NES CHR-RAM BANK SIZE DETECTION MODULE
; =============================================================================

; -----------------------------------------------------------------------------
; SUBROUTINE: detect_chr_ram_size
; DESCRIPTION: Iteratively checks expanding power-of-two CHR banks to locate
;              where memory mirrors back to bank 0, safely logging RAM size.
; -----------------------------------------------------------------------------
.proc detect_chr_ram_size
  VblankWait                      ; Synchronize safely with the next V-Blank
  lda #%00000000                  ; Completely turn off background/sprite 
  sta PPU_CTRL                    ; rendering systems to safely write to PPU
  sta PPU_MASK
  enable_chr_write                ; Unlock memory controller lines for CHR writing

  lda #$00                        ; Target address $0000 in VRAM (Bank 0 start)
  sta PPU_ADDR
  sta PPU_ADDR
  sta chr_ram_size                ; Initialize banking loop tracker at 0
  
  lda #$AA                        ; Write test signature ($AA) to Bank 0
  sta PPU_DATA

  ; ---------------------------------------------------------------------------
  ; LOOP: Test Next Bank Size Boundary
  ; ---------------------------------------------------------------------------
@next_size:
  lda #1                          ; Reset multiplier base shift accumulator
  ldx chr_ram_size                ; Check if we need to bit-shift bank values
  beq @shift_done                 ; If index is 0, bank index is 1 (no shift)

@shift_loop:
  asl A                           ; Shift left to calculate the bank bit-mask
  bcs @end                        ; Exit safely if the register overflows
  dex                             ; Decrement shift counter
  bne @shift_loop                 ; Keep shifting until index is fully exhausted

@shift_done:
  select_chr_bank                 ; Map the calculated bank to VRAM window

  ; Write test value ($AA) to current target bank
  ldx #$00
  stx PPU_ADDR
  stx PPU_ADDR
  lda #$AA
  sta PPU_DATA
  lda #$55                        ; Prevent open-bus read noise matching
  sta PPU_DATA

  ; Verify the written test value ($AA)
  stx PPU_ADDR
  stx PPU_ADDR
  ldy PPU_DATA                     ; Mandatory dummy read to clear internal latch
  lda #$AA
  cmp PPU_DATA                     ; Did the test byte write successfully?
  bne @end                         ; No match implies missing memory or mirroring

  ; Write secondary inverse pattern ($55)
  stx PPU_ADDR
  stx PPU_ADDR
  lda #$55
  sta PPU_DATA
  lda #$AA                        ; Prevent open-bus read noise matching
  sta PPU_DATA

  ; Verify secondary inverse pattern ($55)
  stx PPU_ADDR
  stx PPU_ADDR
  ldy PPU_DATA                    ; Mandatory dummy read to clear internal latch
  lda #$55
  cmp PPU_DATA                    ; Did the inverse byte write successfully?
  bne @end                        ; Exit if target bank fails verification

  ; Check for wrap-around mirroring into bank 0
  lda #0
  select_chr_bank                 ; Switch mapper window back to base bank 0
  stx PPU_ADDR
  stx PPU_ADDR
  ldy PPU_DATA                    ; Mandatory dummy read to clear internal latch
  lda #$AA
  cmp PPU_DATA                    ; Is base pattern intact or overwritten?
  bne @end                        ; If overwritten, we wrapped around. Exit loop.

  inc chr_ram_size                ; Target bank verified. Increment sizing tier.
  bne @next_size                  ; Loop again for next physical power-of-two size

  ; ---------------------------------------------------------------------------
  ; CLEANUP AND ROUTINE EXIT
  ; ---------------------------------------------------------------------------
@end:
  lda #0
  select_chr_bank                 ; Reset mapper to a safe default CHR bank 0
  jsr load_base_chr               ; Restore original layout tileset mapping
  disable_chr_write               ; Lock CHR lines against accidental overwrites
  rts
.endproc

; -----------------------------------------------------------------------------
; HELPER ROUTINES (Saves ROM space by consolidating text prints)
; -----------------------------------------------------------------------------

; Completes PPU layout target address assignment and writes source string pointer
; Inputs: PPU_ADDR (High already set), X = PPU Low, Y = String Low, A = String High
.proc set_ppu_and_text
  sta copy_source_addr+1          ; Save high byte of string source pointer
  sty copy_source_addr            ; Save low byte of string source pointer
  stx PPU_ADDR                    ; Push second byte to finalize PPU cursor target
  jsr print_text                  ; Execute original character rendering loop
  rts
.endproc

; -----------------------------------------------------------------------------
; SUBROUTINE: print_string_direct
; Input parameters:
;   A       - low byte of the string address (copy_source_addr)
;   X       - high byte of the string address (copy_source_addr+1)
; -----------------------------------------------------------------------------
.proc print_string_direct
  sta copy_source_addr          ; Store the LOW byte of the string from Y to memory
  stx copy_source_addr+1        ; Store the HIGH byte of the string from X to memory
  jsr print_text                ; Call your native text rendering function
  rts                           ; Return
.endproc