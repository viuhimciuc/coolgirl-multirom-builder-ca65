;-------------------------------------------------------------------------------
; Variables for game name drawing
;-------------------------------------------------------------------------------
.segment "ZEROPAGE"
text_lines_target:    .res 2 ; text target
draw_text_row:        .res 1
draw_game_name:       .res 2
  ; selected game
selected_game:        .res 2

; Temporary variables
num_lo:               .res 1
num_hi:               .res 1
temp_h:               .res 1
temp_t:               .res 1
temp_o:               .res 1
digit_offset:         .res 1

header_string:        .res 7

; Working variables (in ZP)
val_lo:               .res 1
val_hi:               .res 1

ready_write_header:   .res 1

; constants 
game_names_offset = 4 ; offset for the game names in the nametable, don't change this value, it is used in the cursor movement logic
top_name_offset = 2   ; don't draw the first two lines, they are reserved for the title and instructions , don't change this value, it is used in the cursor movement logic
chars_per_line = 32   ; number of characters per line in the nametable, don't change this value, it is used in the cursor movement logic
lines_per_screen = 16 ; maximum number of lines that can be drawn on the screen, don't change this value, it is used in the cursor movement logic

.segment "CODE"
;===============================================================================
; print_page
; Prints one full page of game names starting from text_lines_target.
;===============================================================================
.proc print_page
  ; Initialize pointer to the current game name
  lda text_lines_target
  sta draw_game_name
  lda text_lines_target + 1
  sta draw_game_name + 1
@print_next_row:
  jsr print_name              ; Print one game name

  ; Move to the next game name
  inc draw_game_name
  lda draw_game_name
  bne @name_game_ok
  inc draw_game_name + 1

@name_game_ok:
  ; Move to the next text row
  inc draw_text_row
  lda draw_text_row
  cmp #lines_per_screen       ; End of page?
  bne @print_next_row

  ; Reset row counter and VRAM address
  lda #0
  sta draw_text_row
  ;VramReset ; Reset the VRAM address
  rts
.endproc

;===============================================================================
; print_name
; Prints a single game name into the current text row on the screen.
;===============================================================================
.proc print_name
  ; Calculate vertical offset for the row
  lda draw_text_row
  clc
  adc #top_name_offset
  sta tmp

  ; Determine target nametable and compute PPU address
  lsr A
  lsr A
  lsr A
  clc
  adc #$20
  bit PPU_STATUS              ; Reset PPU address latch
  sta PPU_ADDR

  lda tmp
  asl A                       ; Multiply by 32 (shift left 5 times)
  asl A
  asl A
  asl A
  asl A
  clc
  adc #game_names_offset
  sta PPU_ADDR

  ; Copy game index into tmp
  lda draw_game_name
  sta tmp
  lda draw_game_name + 1
  sta tmp + 1

  ; Check if index exceeds available game count
  lda tmp
  sec
  sbc #.lobyte(GAMES_COUNT)
  lda tmp + 1
  sbc #.hibyte(GAMES_COUNT)
  bcs @end                    ; If index >= GAMES_COUNT → exit

  ; Select the appropriate PRG bank based on the game index
  lda tmp + 1
  select_prg_bank

  ; Compute address of the pointer to the game name
  lda #.lobyte(game_names)
  clc
  adc tmp
  sta copy_source_addr

  lda #.hibyte(game_names)
  adc #0
  sta copy_source_addr + 1

  ; x2 (because address two bytes length)
  lda copy_source_addr
  clc
  adc tmp
  sta copy_source_addr

  lda copy_source_addr + 1
  adc #0
  sta copy_source_addr + 1

  ; Load actual address of the game name string
  ldy #0
  lda (copy_source_addr), y
  sta tmp
  iny
  lda (copy_source_addr), y
  sta copy_source_addr + 1

  ; Print the game name to PPU
  lda tmp
  sta copy_source_addr
  ldy #0

@text:
  lda (copy_source_addr), y
  beq @end                    ; End of string (0 terminator)
  sta PPU_DATA
  iny
  cpy #chars_per_line - game_names_offset * 2
  bcc @text
@end:
  rts
.endproc

; ---------------------------------------------------------
; convert_number_3digits
; Converts a 16-bit value (num_hi:num_lo) into 3 ASCII digits.
; Supports values 0–999.
; Writes digits into header_string[digit_offset + 0..2].
; ---------------------------------------------------------

; ASCII digit table
digits:
  .byte 205, 206, 207, 208, 209, 210, 211, 212, 213, 214

.proc convert_number_3digits
  ; Load 16-bit value into working registers
  lda num_lo
  sta val_lo
  lda num_hi
  sta val_hi

  ; -----------------------------
  ; Compute hundreds digit
  ; -----------------------------
  ldx #0              ; X = hundreds counter

@hundreds_loop:
  lda val_hi
  bne @hundreds_sub    ; if high byte > 0, value >= 256 → definitely >= 100

  lda val_lo
  cmp #100
  bcc @hundreds_done   ; if <100, stop

@hundreds_sub:
  ; subtract 100 from 16-bit value
  lda val_lo
  sec
  sbc #100
  sta val_lo

  lda val_hi
  sbc #0
  sta val_hi

  inx
  jmp @hundreds_loop

@hundreds_done:
  stx temp_h          ; hundreds digit

  ; -----------------------------
  ; Compute tens digit
  ; -----------------------------
  ldx #0              ; X = tens counter

@tens_loop:
  lda val_hi
  bne @tens_sub        ; if high byte > 0, value >= 256 → definitely >= 10

  lda val_lo
  cmp #10
  bcc @tens_done       ; if <10, stop

@tens_sub:
  ; subtract 10 from 16-bit value
  lda val_lo
  sec
  sbc #10
  sta val_lo

  lda val_hi
  sbc #0
  sta val_hi

  inx
  jmp @tens_loop

@tens_done:
  stx temp_t          ; tens digit

  ; -----------------------------
  ; Ones digit = remaining val_lo
  ; -----------------------------
  lda val_lo
  sta temp_o

  ; -----------------------------
  ; Write digits to header_string
  ; -----------------------------
  ldy digit_offset

  ; hundreds
  lda temp_h
  tax
  lda digits,x
  sta header_string,y

  ; tens
  iny
  lda temp_t
  tax
  lda digits,x
  sta header_string,y

  ; ones
  iny
  lda temp_o
  tax
  lda digits,x
  sta header_string,y
  rts
.endproc

; ---------------------------------------------------------
; make_header_string
; Builds the string: "XYZ in ABC"
; XYZ = selected_game
; ABC = games_count
; ---------------------------------------------------------
; selected_game     is 16-bit: .word 0
; selected_game     = low byte
; selected_game+1   = high byte

.proc make_header_string
  ; Convert selected_game → ASCII (XYZ)
  lda selected_game
  clc
  adc #1
  sta num_lo

  lda selected_game + 1
  adc #0
  sta num_hi

  lda #0
  sta digit_offset
  jsr convert_number_3digits   ; writes XYZ at header_string[0..2]

  ; Write '-' at position 3
  lda #219                     ; ASCII code for '-' in coolgirl-symbols.json
  sta header_string + 3

  ; Convert games_count → ASCII (ABC)
  lda #.lobyte(GAMES_COUNT)
  sta num_lo
  lda #.hibyte(GAMES_COUNT)
  sta num_hi

  lda #4
  sta digit_offset
  jsr convert_number_3digits   ; writes ABC at header_string[4..6]

  ; Null terminator
  lda #0
  sta header_string + 7

  lda #1
  sta ready_write_header

  rts
.endproc

; ---------------------------------------------------------
; write_header_to_ppu
; Writes header_string to the screen at nametable $2000 + offset
; ---------------------------------------------------------
.proc write_header_to_ppu
  lda ready_write_header
  beq @end
; Wait for VBlank
  bit PPU_STATUS
; Set PPU address to top-left + offset (example: row 0, column 2)
  lda #$20        ; high byte of nametable address ($2000)
  sta PPU_ADDR
  lda #$2B        ; low byte: column 2
  sta PPU_ADDR

  ; Write 8 characters from header_string
  ldx #0
@write_loop:
  lda header_string,x
  cmp #0 ; stop at zero
  beq @end_loop
  sta PPU_DATA
  inx
  bne @write_loop
@end_loop:
  sta ready_write_header
@end:
  ;VramReset ; Reset the VRAM address
  rts
.endproc

 ; print null-terminated string from [COPY_SOURCE_ADDR]
.proc print_text
  ldy #0
@loop:
  lda (copy_source_addr), y
  cmp #0 ; stop at zero
  beq @end_loop
  sta PPU_DATA
  iny
  bne @loop
@end_loop:
  rts
.endproc