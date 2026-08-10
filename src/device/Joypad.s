;-------------------------------------------------------------------------------
; Joypad Controller State
;-------------------------------------------------------------------------------
; The state for the controller is stored across two bytes, each of which is a
; bitmask where each bit corresponds to a single button on the controller. This
; demo only uses the first controller.
;
; The bits in each mask are mapped as such:
;
; [AB-+^.<>]
;  ||||||||
;  |||||||+--------> Bit 0: D-PAD Right
;  ||||||+---------> Bit 1: D-PAD Left
;  |||||+----------> Bit 2: D-PAD down
;  ||||+-----------> Bit 3: D-PAD Up
;  |||+------------> Bit 4: Start
;  ||+-------------> Bit 5: Select
;  |+--------------> Bit 6: B
;  +---------------> Bit 7: A
;
;-------------------------------------------------------------------------------

; Button mask bits
BUTTON_A      = 1 << 7
BUTTON_B      = 1 << 6
BUTTON_SELECT = 1 << 5
BUTTON_START  = 1 << 4
BUTTON_UP     = 1 << 3
BUTTON_DOWN   = 1 << 2
BUTTON_LEFT   = 1 << 1
BUTTON_RIGHT  = 1 << 0

.segment "ZEROPAGE"
; Joypad State controller
buttons:              .res 1   ; Button "down" bitmaks, 1 means down & 0 means up.
pressed:              .res 1   ; Button "pressed" bitmask, 1 means pressed this frame.
repeat:               .res 1   ; Button "repeat" auto-repeat event
repeat_cnt:           .res 1   ; Button delay counter
konami_code_state:    .res 1   ; Konami Code state

repeat_delay = 30         ; Initial delay (30 frames)
repeat_rate  = 10         ; Repeat every 10 frames

.segment "CODE"
; ------------------------------------------------------------
; Joypad input handlers (button press/release logic)
; ------------------------------------------------------------
.include "input_handlers.inc"
; ------------------------------------------------------------
; joypad_update
; Handles button press, hold, repeat, and release logic.
; Produces:
;   repeat      – button that should emit a repeat event
;   repeat_cnt  – countdown until next repeat
;   pressed     – newly pressed buttons (edge-triggered)
;   buttons     – currently held buttons
; ------------------------------------------------------------
.proc joypad_update
  jsr read_joypad1        ; Read current joypad state
  jsr check_buttons       ; Process button events

  lda #0
  sta repeat              ; Default: no repeat event

  ; --------------------------------------------------------
  ; If a new button was pressed (edge-trigger)
  ; --------------------------------------------------------
  lda pressed
  beq @held               ; If none, go check held state

  sta repeat              ; Emit event immediately
  lda #repeat_delay       ; Start initial delay before repeats
  sta repeat_cnt
  rts

; ------------------------------------------------------------
; @held — handle held buttons and repeat timing
; ------------------------------------------------------------
@held:
  lda buttons
  beq @release            ; No buttons held → go to release logic

  dec repeat_cnt          ; Countdown until next repeat
  bne @done               ; Not yet zero → nothing to do

  ; Time to emit a repeat event
  lda buttons
  sta repeat

  lda #repeat_rate        ; Set repeat interval
  sta repeat_cnt
@done:
  rts

; ------------------------------------------------------------
; .release — no buttons held, reset repeat counter
; ------------------------------------------------------------
@release:
  lda #0
  sta repeat_cnt
  rts

.endproc

 ; ------------------------------------------------------------
; read_joypad1
; Reads joypad #1 and updates:
;   buttons – currently held buttons
;   pressed – newly pressed buttons (edge-trigger)
; ------------------------------------------------------------
.proc read_joypad1
  lda buttons             ; Save previous button state
  tay

  lda #1                  ; Strobe joypad
  sta JOYPAD1
  sta buttons

  lsr A                   ; Clear strobe
  sta JOYPAD1

@loop:
  lda JOYPAD1             ; Read serial bit
  lsr A
  rol buttons             ; Shift into button register
  bcc @loop               ; Continue until latch bit ends

  ; Compute newly pressed buttons:
  ; pressed = (~old & new)
  tya                     ; old buttons
  eor buttons             ; bits that changed
  and buttons             ; keep only new presses
  sta pressed
  rts

.endproc

; ------------------------------------------------------------
; check_buttons
; Dispatches actions based on newly pressed buttons.
; ------------------------------------------------------------
.proc check_buttons
  lda pressed
  cmp #$00
  bne @start_check        ; If any button pressed → continue
  rts                     ; Otherwise exit

@start_check:
  jsr konami_code_check   ; Check Konami code sequence

; ------------------------------------------------------------
; Button A handler
; ------------------------------------------------------------
@button_a:
  lda pressed
  and #BUTTON_A
  beq @button_b
  jmp start_game          ; A starts the game

; ------------------------------------------------------------
; Button B handler
; ------------------------------------------------------------
@button_b:
  lda pressed
  and #BUTTON_B
  beq @button_start
  jmp @button_end         ; B does nothing

; ------------------------------------------------------------
; Button START handler
; ------------------------------------------------------------
@button_start:
  lda pressed
  and #BUTTON_START
  beq @button_end
  jmp start_game          ; START also starts the game

@button_end:
  rts
.endproc

; ------------------------------------------------------------
; konami_code_check
; Checks if the newly pressed button matches the Konami code.
; Updates konami_code_state accordingly.
; ------------------------------------------------------------
.proc konami_code_check
  ldy konami_code_state      ; Current position in code
  lda konami_code, y          ; Expected button
  cmp pressed
  bne @konami_code_check_fail  ; Mismatch → reset logic

  iny                         ; Correct button → advance
  jmp @konami_code_check_end

; ------------------------------------------------------------
; Mismatch: reset to beginning, but allow restarting if
; the new pressed button matches the first code button.
; ------------------------------------------------------------
@konami_code_check_fail:
  ldy #0
  lda konami_code             ; First button of the code
  cmp pressed
  bne @konami_code_check_end   ; Still mismatch → stay at 0
  iny                         ; Match → move to next

@konami_code_check_end:
  sty konami_code_state
  rts
.endproc

; ------------------------------------------------------------
; Konami code sequence data
; ------------------------------------------------------------
.segment "RODATA"
konami_code:
  .byte BUTTON_UP, BUTTON_UP, BUTTON_DOWN, BUTTON_DOWN
  .byte BUTTON_LEFT, BUTTON_RIGHT, BUTTON_LEFT, BUTTON_RIGHT
  .byte BUTTON_B, BUTTON_A

konami_code_length:
  .byte 10