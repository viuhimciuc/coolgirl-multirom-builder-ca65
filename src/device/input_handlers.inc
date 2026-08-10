; ============================================================
; input_handlers.inc
; ------------------------------------------------------------
; Universal input handlers for menu navigation:
;   - Page scrolling (LEFT / RIGHT)
;   - Cursor movement (UP / DOWN)
;
; Designed for NESASM (6502) — no macros, no ca65 syntax.
; Clean, stable, readable, and safe for large projects.
; ============================================================


; ============================================================
; External variables (must be defined in ZEROPAGE in main file)
; ------------------------------------------------------------
; scroll_dir          : +1 (RIGHT) or -1 (LEFT)
; scroll_button_mask  : BUTTON_RIGHT or BUTTON_LEFT
; cursor_dir          : +1 (DOWN) or -1 (UP)
; cursor_button_mask  : BUTTON_UP or BUTTON_DOWN
;
; selected_game       : 16-bit index of selected item
; text_lines_target   : 16-bit index of top visible line
; repeat              : controller repeat mask
;
; GAMES_COUNT         : total number of items
; lines_per_screen    : items per page
;
; set_cursor_target   : routine to update cursor position
; ============================================================
.segment "ZEROPAGE"
; Variables for cursor movement and button state
scroll_dir:            .res 1 ; Direction of scrolling, 1 for right/down, $FF for left/up
scroll_button_mask:    .res 1 ; Button mask for scrolling, e.g., BUTTON_RIGHT or BUTTON_DOWN
cursor_dir:            .res 1 ; Direction of cursor movement, 1 for down, $FF for up
cursor_button_mask:    .res 1 ; Button mask for cursor movement, e.g., BUTTON_DOWN or BUTTON_UP

; ============================================================
; Helper constants
; ------------------------------------------------------------
; last_page_start = (GAMES_COUNT / lines_per_screen) * lines_per_screen
; ============================================================

last_page_start_low  = ((GAMES_COUNT / lines_per_screen) * lines_per_screen) & $FF
last_page_start_high = ((GAMES_COUNT / lines_per_screen) * lines_per_screen) >> 8

.segment "CODE"
; ============================================================
; PAGE SCROLL HANDLER (LEFT / RIGHT)
; ------------------------------------------------------------
; scroll_dir:
;   +1 → scroll forward (RIGHT)
;   -1 → scroll backward (LEFT)
;
; scroll_button_mask:
;   BUTTON_RIGHT or BUTTON_LEFT
; ============================================================

.proc scroll_page

    ; Check if the scroll button is pressed
    lda repeat
    and scroll_button_mask
    bne @check_direction
    jmp @end

@check_direction:
    ; Check direction
    lda scroll_dir
    bpl @forward

; ------------------------------------------------------------
; BACKWARD SCROLL (LEFT)
; ------------------------------------------------------------
@backward:
    ; text_lines_target -= lines_per_screen
    lda text_lines_target
    sec
    sbc #lines_per_screen
    sta text_lines_target
    lda text_lines_target+1
    sbc #0
    sta text_lines_target+1

    ; selected_game -= lines_per_screen
    lda selected_game
    sec
    sbc #lines_per_screen
    sta selected_game
    lda selected_game+1
    sbc #0
    sta selected_game+1

    jmp @check_bounds

; ------------------------------------------------------------
; FORWARD SCROLL (RIGHT)
; ------------------------------------------------------------
@forward:
    ; text_lines_target += lines_per_screen
    lda text_lines_target
    clc
    adc #lines_per_screen
    sta text_lines_target
    lda text_lines_target+1
    adc #0
    sta text_lines_target+1

    ; selected_game += lines_per_screen
    lda selected_game
    clc
    adc #lines_per_screen
    sta selected_game
    lda selected_game+1
    adc #0
    sta selected_game+1

; ------------------------------------------------------------
; BOUNDS CHECKING (both directions)
; ------------------------------------------------------------
@check_bounds:
    ; If scroll_dir >= 0 → forward bounds
    lda scroll_dir
    bpl @check_forward

; ------------------------------------------------------------
; BACKWARD UNDERFLOW (page < 0)
; ------------------------------------------------------------
@check_backward:
    lda text_lines_target+1
    bpl @cursor_update      ; still >= 0 → OK

    ; Underflow → jump to last page
    lda #last_page_start_low
    sta text_lines_target
    lda #last_page_start_high
    sta text_lines_target+1

    ; Clamp selected_game to last item
    lda #.lobyte(GAMES_COUNT-1)
    sta selected_game
    lda #.hibyte(GAMES_COUNT-1)
    sta selected_game+1

    jmp @cursor_update

; ------------------------------------------------------------
; FORWARD OVERFLOW (past last page)
; ------------------------------------------------------------
@check_forward:
    ; If text_lines_target >= games_count → wrap to zero
    lda text_lines_target+1
    cmp #.hibyte(GAMES_COUNT)
    bne @continue_forward_check
    lda text_lines_target
    cmp #.lobyte(GAMES_COUNT)
    bcs @wrap_to_zero

@continue_forward_check:
    ; Compare text_lines_target with last_page_start
    lda text_lines_target+1
    cmp #last_page_start_high
    bcc @cursor_update
    lda text_lines_target
    cmp #last_page_start_low
    bcc @cursor_update
    beq @clamp_last_page


@wrap_to_zero:
    ; Overflow → wrap to beginning
    lda #0
    sta text_lines_target
    sta text_lines_target+1
    sta selected_game
    sta selected_game+1
    jmp @cursor_update

; ------------------------------------------------------------
; Clamp selected_game to last item
; ------------------------------------------------------------
@clamp_last_page:
    lda selected_game+1
    cmp #.hibyte(GAMES_COUNT-1)
    bcc @cursor_update
    bne @set_last_game

    lda selected_game
    cmp #.lobyte(GAMES_COUNT-1)
    bcc @cursor_update

@set_last_game:
    lda #.lobyte(GAMES_COUNT-1)
    sta selected_game
    lda #.hibyte(GAMES_COUNT-1)
    sta selected_game+1

; ------------------------------------------------------------
; Update cursor
; ------------------------------------------------------------
@cursor_update:
    jsr set_cursor_target  ; Set cursor targets
@end:
    rts
.endproc

; ============================================================
; CURSOR MOVEMENT HANDLER (UP / DOWN)
; ------------------------------------------------------------
; cursor_dir:
;   +1 → DOWN
;   -1 → UP
;
; cursor_button_mask:
;   BUTTON_UP or BUTTON_DOWN
; ============================================================

.proc move_cursor

    ; Check if cursor button is pressed
    lda repeat
    and cursor_button_mask
    beq @end

    ; Check direction
    lda cursor_dir
    bpl @down

; ------------------------------------------------------------
; CURSOR UP
; ------------------------------------------------------------
@up:
    ; selected_game -= 1
    lda selected_game
    sec
    sbc #1
    sta selected_game
    lda selected_game+1
    sbc #0
    sta selected_game+1

    ; Underflow? (high byte negative)
    lda selected_game+1
    bmi @up_underflow

    jmp @cursor_update

@up_underflow:
    ; Wrap to last game
    lda #.lobyte(GAMES_COUNT-1)
    sta selected_game
    lda #.hibyte(GAMES_COUNT-1)
    sta selected_game+1

    ; Move text window to last page
    lda #last_page_start_low
    sta text_lines_target
    lda #last_page_start_high
    sta text_lines_target+1

    jmp @cursor_update_off_make_header

; ------------------------------------------------------------
; CURSOR DOWN
; ------------------------------------------------------------
@down:
    ; selected_game += 1
    lda selected_game
    clc
    adc #1
    sta selected_game
    lda selected_game+1
    adc #0
    sta selected_game+1

    ; Overflow? selected_game == GAMES_COUNT
    lda selected_game+1
    cmp #.hibyte(GAMES_COUNT)
    bne @cursor_update
    lda selected_game
    cmp #.lobyte(GAMES_COUNT)
    bne @cursor_update

    ; Wrap to first item
    lda #0
    sta selected_game
    sta selected_game+1
    sta text_lines_target
    sta text_lines_target+1
    jmp @cursor_update_off_make_header
    
; ------------------------------------------------------------
; Update cursor
; ------------------------------------------------------------
@cursor_update:
    jsr make_header_string   ; 1st Update the header string based on the current cursor position
@cursor_update_off_make_header:
    jsr set_cursor_target    ; 2nd Set cursor targets
@end:
    rts
.endproc