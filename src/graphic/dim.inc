; =============================================================================
; TITLE:   NON-BLOCKING PALETTE FADE SYSTEM WITH SAFE NMI DRAW SYNCHRONIZATION
; AUTHOR:  viuhimciuc and AI NES Development Collaborator
; TARGET:  ca65 Compiler (6502 Assembly for Nintendo Entertainment System)
; =============================================================================
; DESCRIPTION:
; This is an advanced, non-blocking palette dimming engine (Fade In / Fade Out) 
; designed specifically for NES games utilizing active NMI frame interrupts. 
;
; Unlike traditional blocking loops that freeze execution, this engine uses a 
; state-machine layout. It processes only one tiny brightness step per frame, 
; allowing your main game thread to run at full 60 FPS. This ensures player/enemy 
; sprites continue to move, update positions, and animate during the fade effect.
;
; FEATURES:
; 1. Dual Mode Operation: 
;    - Option 1: Modifies Background only (16 bytes) leaving sprites untouched.
;    - Option 2: Modifies Background + Sprites (32 bytes) simultaneously.
;
; 2. Race-Condition Protection (Safe Draw Synchronization):
;    When the fade finishes, the system forces a 1-frame buffering buffer delay. 
;    It waits for the NMI handler to completely finish pushing the final palette 
;    cache into the PPU during V-Blank. Once applied, it fires a strict ONE-TIME 
;    trigger (`bg_request_draw`) to update your background graphics safely without 
;    causing display glitches or cyclic drawing overhead.
;
; USAGE DIRECTION:
; - Load your master target colors into `palette_orig`.
; - Trigger an effect once using `jsr Start_FadeIn` or `jsr Start_FadeOut` (pass 
;   mode parameter in Accumulator: #0 for BG-only, #1 for full 32-byte mode).
; - Execute `jsr Update_Palette_Fade` inside your main loop every single frame.
; - Poll the `bg_request_draw` flag in your Game Loop to execute your custom 
;   background rendering logic exactly once upon transition completion.
; =============================================================================
.segment "ZEROPAGE"
fade_step:             .res 1       ; Effect state (0 = inactive, 1-4 = active fade steps)
fade_delay:            .res 1       ; Frame counter to control the speed of the transition
fade_mode:             .res 1       ; Mode flag: 0 = BG only (16 bytes), 1 = BG + Sprites (32 bytes)
fade_direction:        .res 1       ; Direction flag: 0 = Fade Out (darkening), 1 = Fade In (brightening)
bg_request_draw:       .res 1       ; 1 = draw background (one-time request), 0 = do nothing
fade_waiting_for_nmi:  .res 1       ; 1 = the final palette has been sent to NMI; we are awaiting its implementation.
temp_x:                .res 1       ; Temporary storage for X register loops
temp_x2:               .res 1       ; Additional temporary storage for loops

.segment "CODE"
; =============================================================================
; START FADE OUT EFFECT (Darkening)
; Input: A = 0 (BG only), A = 1 (BG + Sprites)
; =============================================================================
.proc Start_FadeOut
  sta fade_mode
  lda #0
  sta fade_direction       ; Set direction to Darken
  sta fade_waiting_for_nmi ; Reset NMI sync wait flag
  lda #4
  sta fade_step            ; Start at step 4 and decrement downwards
  lda #1
  sta fade_delay           ; Execute processing instantly on the next frame
  rts
.endproc
; =============================================================================
; START FADE IN EFFECT (Brightening from pure black)
; Input: A = 0 (BG only), A = 1 (BG + Sprites)
; Make sure your clean target palette is already copied into palette_orig!
; =============================================================================
.proc Start_FadeIn
  sta fade_mode
  lda #1
  sta fade_direction       ; Set direction to Brighten
  lda #0
  sta fade_waiting_for_nmi ; Reset NMI sync wait flag
  lda #4
  sta fade_step            ; Start at full darkness level
  lda #1
  sta fade_delay

  ; Force initialize cache to full darkness ($1D) to prevent bright flashes
  ldx #0
@fill_dark:
  lda #$1D
  sta palette_cache, x
  inx
  cpx #32
  bne @fill_dark
  SetPalettesFlag           ; Signal NMI to apply pure black screen immediately
  rts
.endproc
; =============================================================================
; UPDATE PALETTE FADE STATE MACHINE
; Call this once per frame in your main Game Loop thread
; =============================================================================
.proc Update_Palette_Fade
  lda fade_step
  bne @do_fade            ; If fade_step == 0, no effect is running -> Exit
  jmp @done

@do_fade:
  dec fade_delay          ; Decrement frame delay counter
  beq @do_fade_delay      ; If the time for the next step hasn't arrived -> Exit
  jmp @done

@do_fade_delay:
  lda #6
  sta fade_delay          ; Reset delay (6 frames per brightness tier. Adjust to change speed!)

  ; Check transition direction
  lda fade_direction
  bne @do_fade_in

; -----------------------------------------------------------------------------
; L0GIC: FADE OUT STEP
; -----------------------------------------------------------------------------
@do_fade_out:
  ldx #0
  lda fade_mode
  bne @fo_size_32
  ldy #16                 ; Target boundary: 16 bytes
  jmp @fo_loop
@fo_size_32:
  ldy #32                 ; Target boundary: 32 bytes

@fo_loop:
  lda palette_cache, x
  sec
  sbc #$10                ; Drop brightness down by one row in the NES color table
  bpl @fo_not_minus
  lda #$1D                ; Cap at safe black color ($1D) if value goes negative
@fo_not_minus:
  cmp #$0D
  bne @fo_not_bad
  lda #$1D                ; Avoid dangerous color $0D (can glitch certain TVs)
@fo_not_bad:
  sta palette_cache, x
  inx
  stx temp_x
  txa
  cpy temp_x              ; Compare loop counter with our boundary register (Y)
  bne @fo_loop

  dec fade_step           ; Advance state machine step counter
  jmp @apply_and_exit

; -----------------------------------------------------------------------------
; LOGIC: FADE IN STEP
; -----------------------------------------------------------------------------
@do_fade_in:
  ; Convert step (4, 3, 2, 1) into a subtraction mask ($30, $20, $10, $00)
  ldx fade_step
  dex
  txa 
  asl a
  asl a
  asl a
  asl a
  sta temp_x              ; temp_x now holds the current darkness offset modifier

  ldx #0
  lda fade_mode
  bne @fi_size_32
  ldy #16
  jmp @fi_loop
@fi_size_32:
  ldy #32

@fi_loop:
  lda palette_orig, x     ; Fetch target master color
  sec
  sbc temp_x              ; Apply the darkness offset modifier
  bpl @fi_not_minus
  lda #$1D                ; Clamp to safe black if underflow occurs
@fi_not_minus:
  cmp #$0D
  bne @fi_not_bad
  lda #$1D                ; Fix potential $0D display issues
@fi_not_bad:
  sta palette_cache, x    ; Store into cache buffer for NMI processing
  inx
  stx temp_x2
  txa
  cpy temp_x2             ; Loop verification
  bne @fi_loop

  dec fade_step           ; Advance step counter closer to clean original palette

; -----------------------------------------------------------------------------
; UPDATE EMISSION FLAGGING & COMPLETION CHECK
; -----------------------------------------------------------------------------
@apply_and_exit:
  SetPalettesFlag           ; Notify NMI that cache is modified and ready to push

  ; Check if the animation steps just finished
  lda fade_step
  bne @still_running      ; If fade_step is NOT zero -> effect is still running, exit

  ; -------------------------------------------------------------------------
  ; This block runs EXACTLY ONCE on the frame when fade_step hits 0
  ; -------------------------------------------------------------------------
  lda fade_direction
  bne @skip_fade_out_trigger ; If fade_direction == 1 (Fade In) -> skip trigger

  ; If we are here, it means Fade Out has successfully finished!
  lda #1
  sta bg_request_draw     ; Trigger the ONE-TIME background draw request

@skip_fade_out_trigger:
  lda #1
  sta fade_waiting_for_nmi ; Set wait flag so the next frame passes safely

@still_running:
  rts

; -----------------------------------------------------------------------------
; BACKGROUND SYNCHRONIZATION BLOCK (Jumped here via beq @done from the start)
; -----------------------------------------------------------------------------
@done:
  lda fade_waiting_for_nmi
  beq @exit_instantly     ; If we are not waiting for NMI -> exit instantly

  ; 1 frame has successfully passed since the last palette data was sent.
  ; The PPU now safely holds the final black palette.
  lda #0
  sta fade_waiting_for_nmi ; Reset the safety wait flag

  ; NOTE: Your Game Loop will see bg_request_draw == 1 on this frame!

@exit_instantly:
  rts
.endproc
; ==============================================================================
; NMI FRAME SYNCHRONIZATION (WAIT NEXT V-BLANK)
; ==============================================================================
.proc Wait_Next_Frame
  SetPalettesFlag
@loop:
  bit nmi_ready_palettes  ; Read the current status of the NMI flag
  bmi @loop               ; Loop continuously while flag is active (!= 0)
  
  rts                     ; Return once NMI handler clears nmi_ready to 0
.endproc
; ==============================================================================
; PALETTE FADE-OUT EFFECT ENGINE
; Input: A = 0 (Fade Background only / 16 bytes), A = 1 (Fade All / 32 bytes)
; ==============================================================================
.proc Palette_FadeOut
  sta fade_mode             ; Save selected mode (0 = BG only, 1 = BG + Sprites)
  lda #4
  sta fade_step             ; Set total fade steps (4 brightness levels)

  VblankWait                ; Wait for V-Blank sync
  EnableNMI                 ; Enable NMI

@step_loop:
  lda #2
  sta fade_delay            ; Initialize frame delay counter (4 frames per step)
@delay_loop:
  VblankWait                ; Wait for V-Blank sync
  dec fade_delay
  bne @delay_loop           ; Loop until 4 frames have passed

  ; Determine the loop boundary based on fade_mode
  ldx #0                    ; Start index at first color byte
  lda fade_mode
  bne @mod_loop_32          ; If fade_mode != 0, process all 32 bytes

; ------------------------------------------------------------------------------
; Inner Loop: Processes Background Palette Only (16 Bytes)
; ------------------------------------------------------------------------------
@mod_loop_16:
  lda palette_cache, x      ; Read current color byte from cache
  sec
  sbc #$10                  ; Decrease brightness by one palette row
  bpl @check_black_16       ; If result is positive, skip enforcing pure black
  lda #$1D                  ; Enforce safe black color ($1D)
@check_black_16:
  cmp #$0D                  ; Check for the problematic "bad black" color ($0D)
  bne @store_color_16
  lda #$1D                  ; Replace safe black to prevent display sync issues
@store_color_16:
  sta palette_cache, x      ; Save modified color back to cache
  inx                       ; Move to next color index
  cpx #16                   ; Check if 16 bytes have been processed
  bne @mod_loop_16          ; Continue loop if index < 16
  beq @signal_nmi           ; Skip 32-byte processing loop entirely

; ------------------------------------------------------------------------------
; Inner Loop: Processes Full Palette (32 Bytes, BG + Sprites)
; ------------------------------------------------------------------------------
@mod_loop_32:
  lda palette_cache, x      ; Read current color byte from cache
  sec
  sbc #$10                  ; Decrease brightness by one palette row
  bpl @check_black_32       ; If result is positive, skip enforcing pure black
  lda #$1D                  ; Enforce safe black color ($1D)
@check_black_32:
  cmp #$0D                  ; Check for the problematic "bad black" color ($0D)
  bne @store_color_32
  lda #$1D                  ; Replace safe black to prevent display sync issues
@store_color_32:
  sta palette_cache, x      ; Save modified color back to cache
  inx                       ; Move to next color index
  cpx #32                   ; Check if all 32 bytes have been processed
  bne @mod_loop_32          ; Continue loop if index < 32

; ------------------------------------------------------------------------------
; Synchronize with NMI Handler to Update PPU Hardware Palettes
; ------------------------------------------------------------------------------
@signal_nmi:
  jsr Wait_Next_Frame       ; Alert NMI that the cache is modified and ready to push
  
  dec fade_step             ; Decrement total fade steps remaining
  bne @step_loop            ; Repeat until screen is fully darkened

  VblankWait                ; wait for v-blank
  lda #%00000000            ; Disable PPU
  sta PPU_CTRL
  sta PPU_MASK
  rts                       ; Return from subroutine
.endproc
; ==============================================================================
; PALETTE FADE-IN EFFECT ENGINE
; Input: A = 0 (Fade Background only / 16 bytes), A = 1 (Fade All / 32 bytes)
; Prerequisites: Clean master palette must already be stored in palette_orig
; ==============================================================================
.proc Palette_FadeIn
  sta fade_mode             ; Save selected mode (0 = BG only, 1 = BG + Sprites)

  ; Step 1: Gradually phase the colors back in over 4 hardware brightness steps
  lda #4
  sta fade_step             ; Step 4 = Max darkness masking ($30 offset)

  ; Step 2: Initialize the palette cache with complete darkness ($1D)
  ldx #0
  lda #$1D                  ; Load safe black color code once
@fill_dark:
  sta palette_cache, x      ; Force black into cache index
  inx
  cpx #32                   ; Clear all 32 bytes (BG + Sprite ranges)
  bne @fill_dark

  EnableNMI                 ; Enable NMI
  jsr Wait_Next_Frame       ; Alert NMI to render the solid black frame immediately
  lda #BG_ON|OBJ_OFF        ; Enable Rendering only background
  sta PPU_MASK

@step_loop:
  lda #2
  sta fade_delay            ; Initialize frame delay counter (4 frames per step)
@delay_loop:
  VblankWait                ; Wait for V-Blank sync
  dec fade_delay
  bne @delay_loop           ; Loop until 4 frames have passed

  ; Calculate the subtraction offset for the current brightness phase:
  ; Step 4 -> Subtract $30 (Black screen)
  ; Step 3 -> Subtract $20 (Very Dim)
  ; Step 2 -> Subtract $10 (Dim)
  ; Step 1 -> Subtract $00 (Original pure colors)
  ldx fade_step
  dex 
  txa                       ; Convert 1-based step counter to 0-based offset range (3, 2, 1, 0)
  asl a                     ; Shift left 4 times to scale into upper nibble matrix
  asl a
  asl a
  asl a                     ; Value is now transformed into either $30, $20, $10, or $00
  sta fade_delay           ; Temporarily repurpose delay variable to store current subtract offset

  ldx #0                    ; Reset master color index pointer
  lda fade_mode
  bne @mod_loop_32          ; If fade_mode != 0, process all 32 bytes (BG + Sprites)

; ------------------------------------------------------------------------------
; Inner Loop: Processes Background Palette Only (16 Bytes)
; ------------------------------------------------------------------------------
@mod_loop_16:
  lda palette_orig, x       ; Fetch clean master color
  sec
  sbc fade_delay           ; Apply the current phase darkness masking offset
  bpl @check_black_16       ; If result is within positive bounds, skip clip logic
  lda #$1D                  ; If underflowed past zero, clip it cleanly to black
@check_black_16:
  cmp #$0D                  ; Check for the problematic "bad black" color ($0D)
  bne @store_color_16
  lda #$1D                  ; Force shift to safe black color ($1D)
@store_color_16:
  sta palette_cache, x      ; Push color into active NMI update cache
  inx
  cpx #16                   ; Check if background boundary has been reached
  bne @mod_loop_16          ; Loop if index < 16
  beq @signal_nmi           ; Skip sprite loop processing entirely

; ------------------------------------------------------------------------------
; Inner Loop: Processes Full Palette (32 Bytes, BG + Sprites)
; ------------------------------------------------------------------------------
@mod_loop_32:
  lda palette_orig, x       ; Fetch clean master color
  sec
  sbc fade_delay           ; Apply the current phase darkness masking offset
  bpl @check_black_32       ; If result is within positive bounds, skip clip logic
  lda #$1D                  ; If underflowed past zero, clip it cleanly to black
@check_black_32:
  cmp #$0D                  ; Check for the problematic "bad black" color ($0D)
  bne @store_color_32
  lda #$1D                  ; Force shift to safe black color ($1D)
@store_color_32:
  sta palette_cache, x      ; Push color into active NMI update cache
  inx
  cpx #32                   ; Check if full palette boundary has been reached
  bne @mod_loop_32          ; Loop if index < 32

; ------------------------------------------------------------------------------
; Synchronize with NMI Handler to Update PPU Hardware Palettes
; ------------------------------------------------------------------------------
@signal_nmi:
  jsr Wait_Next_Frame       ; Alert NMI that updated frame colors are ready to draw
  
  dec fade_step             ; Advance to the next brightness stage
  bne @step_loop            ; Repeat until screen is entirely lit to full intensity

  VblankWait                ; wait for v-blank
  DisableNMI                ; Disable NMI
  rts                       ; Return from subroutine
.endproc