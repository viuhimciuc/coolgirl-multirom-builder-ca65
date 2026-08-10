; ==============================================================================
; Table of speed and tile data for sprite animations
; ==============================================================================
.segment "RODATA"
  ; Delay values for animation frames based on velocity
delay_by_velocity:
  .byte 12, 11, 11, 11, 11, 11, 10, 10, 10, 10, 10
  .byte 9, 9, 9, 9, 9, 8, 8, 8, 8, 8, 7, 7, 7, 7, 7
  .byte 6, 6, 6, 6, 6, 5, 5, 5, 5, 5, 4, 4, 4, 4, 4
  ; Tile for fall indices for animation frames
fall_tiles:
  .byte $14, $16, $15, $15, $16, $14, $00, $00
  ; Tile for fly indices for animation frames
fly_up_tiles:
  .byte $11, $13, $12, $12, $13, $11, $00, $00
  .byte $14, $16, $15, $15, $16, $14, $00, $00
  .byte $17, $19, $18, $18, $19, $17, $00, $00
  .byte $14, $16, $15, $15, $16, $14, $00, $00
  ; Bonfire animation tiles
bonfire_tiles:
  .byte $2B, $2D, $2C, $2E, $1B, $1D, $1C, $1E
  ; Sprite tile for down definitions for Cursor
fall_tiles_cursor:
  .byte $43, $44, $44, $43
  ; Sprite tile foe up definitions for Cursor
fly_up_tiles_cursor:
  .byte $41, $42, $42, $41
  .byte $43, $44, $44, $43
  .byte $45, $46, $46, $45
  .byte $43, $44, $44, $43

; ==============================================================================
; Sprite1 (Gull1) State (Movement, Animation, etc.)
; ==============================================================================
.segment "ZEROPAGE"
velocityX1:              .res 1 ; Signed Fixed Point 4.4
positionX1:              .res 2 ; Signed Fixed Point 12.4
spriteX1:                .res 1 ; Unsigned Screen Coordinates
heading1:                .res 1 ; See `.enum Heading`, below...

velocityY1:              .res 1 ; Signed Fixed Point 4.4
positionY1:              .res 2 ; Signed Fixed Point 12.4
spriteY1:                .res 1 ; Unsigned Screen Coordinates

motionState1:            .res 1 ; See `.enum MotionState`, below...
animationFrame1:         .res 1 ; Current animation frame index
animationTimer1:         .res 1 ; Timer for animation frame updates

; ------------------------------------------------------------------------------
; Processing subroutine Sprite1 (Gull1) (Movement, Animation, etc.)
; ------------------------------------------------------------------------------
.segment "CODE"
spriteX_init1 = 7
velocityX_init1 = 4
positionX_LO_init1 = $70
positionX_HI_init1 = $00

spriteY_init1 = 80
velocityY_init1 = 254
positionY_LO_init1 = $00
positionY_HI_init1 = $05

MotionState_FlyUp1 = 0
MotionState_Fall1  = 1

; ------------------------------------------------------------------------------
; Initialize Gull1 sprite state
; ------------------------------------------------------------------------------
.proc play_gull1_init
  jsr init_x1
  jsr init_y1
  jsr init_sprite_gull1
  rts
.endproc

; ------------------------------------------------------------------------------
; Initialize X position and velocity
; ------------------------------------------------------------------------------
.proc init_x1
  ; Set the initial x-position to 7 ($0070 in 12.4 fixed point)
  lda #spriteX_init1
  sta spriteX1
  lda #positionX_LO_init1
  sta positionX1
  lda #positionX_HI_init1
  sta positionX1 + 1
  ; Initialize the velocity
  lda #velocityX_init1
  sta velocityX1
  rts
.endproc

; ------------------------------------------------------------------------------
; Initialize Y position and velocity
; ------------------------------------------------------------------------------
.proc init_y1
  ; Set the initial y-position to 7 ($0800 in 12.4 fixed point)
  lda #spriteY_init1
  sta spriteY1
  lda #positionY_LO_init1
  sta positionY1
  lda #positionY_HI_init1
  sta positionY1 + 1
  ; Initialize the velocity
  lda #velocityY_init1
  sta velocityY1
  rts
.endproc

; ------------------------------------------------------------------------------
; Initialize Gull1 sprite graphics in OAM
; ------------------------------------------------------------------------------
.proc init_sprite_gull1
  NUM_SPRITES1 = 3
  LEFT_TILE1 = $11
  CENTER_TILE1 = $12
  RIGHT_TILE1 = $13
  ATTRS1 = %00000010
  ldx #0
@loop:
  lda initial_sprite_gull1, x
  sta $200, x
  inx
  cpx #(4 * NUM_SPRITES1)
  bne @loop
  rts
initial_sprite_gull1:
  .byte spriteY_init1, LEFT_TILE1, ATTRS1, spriteX_init1
  .byte spriteY_init1, CENTER_TILE1, ATTRS1, spriteX_init1 + 8
  .byte spriteY_init1, RIGHT_TILE1, ATTRS1, spriteX_init1 + 16
.endproc

; ------------------------------------------------------------------------------
; Update Gull1 sprite state
; ------------------------------------------------------------------------------
.proc gull1_update
  jsr apply_velocity_y1
  jsr apply_velocity_x1
  jsr bound_position_y1
  jsr bound_position_x1
  jsr sprite1_update
  rts
.endproc

; ------------------------------------------------------------------------------
; Apply Y velocity to position
; ------------------------------------------------------------------------------
.proc apply_velocity_y1
  ; Check to see if we're moving to the down (positive) or the up (negative)
  lda velocityY1
  bmi @negative
@positive:
  ; Positive velocity is easy: just add the 4.4 fixed point velocity to the
  ; 12.4 fixed point position.
  clc
  adc positionY1
  sta positionY1
  lda #0
  adc positionY1 + 1
  sta positionY1 + 1
  rts
@negative:
  lda #0
  sec
  sbc velocityY1
  sta tmp
  lda positionY1
  sec
  sbc tmp
  sta positionY1
  lda positionY1 + 1
  sbc #0
  sta positionY1 + 1
  rts
.endproc

; ------------------------------------------------------------------------------
; Apply X velocity to position
; ------------------------------------------------------------------------------
.proc apply_velocity_x1
  ; Check to see if we're moving to the right (positive) or the left (negative)
  lda velocityX1
  bmi @negative
@positive:
  ; Positive velocity is easy: just add the 4.4 fixed point velocity to the
  ; 12.4 fixed point position.
  clc
  adc positionX1
  sta positionX1
  lda #0
  adc positionX1 + 1
  sta positionX1 + 1
  rts
@negative:
  lda #0
  sec
  sbc velocityX1
  sta tmp
  lda positionX1
  sec
  sbc tmp
  sta positionX1
  lda positionX1 + 1
  sbc #0
  sta positionX1 + 1
  rts
.endproc

; ------------------------------------------------------------------------------
; Bound Y position within screen limits
; ------------------------------------------------------------------------------
.proc bound_position_y1
  ; Convert the fixed point position coordinate into screen coordinates
  lda positionY1
  sta tmp
  lda positionY1 + 1
  sta tmp + 1
  lsr tmp + 1
  ror tmp
  lsr tmp + 1
  ror tmp
  lsr tmp + 1
  ror tmp
  lsr tmp + 1
  ror tmp
  ; Assume that everything is fine and save the sprite position
  lda tmp
  sta spriteY1
  ; Check if we are moving up(negative)
  cmp #10
  bcc @not_hittop
  rts
@not_hittop:
  lda #$03
  sta velocityY1
  lda velocityX1
  bmi @left
  lda #$06
  sta velocityX1
  rts
@left:
  lda #$FA
  sta velocityX1
  rts
.endproc

; ------------------------------------------------------------------------------
; Bound X position within screen limits
; ------------------------------------------------------------------------------
.proc bound_position_x1
  ; Convert the fixed point position coordinate into screen coordinates
  lda positionX1
  sta tmp
  lda positionX1 + 1
  sta tmp + 1
  lsr tmp + 1
  ror tmp
  lsr tmp + 1
  ror tmp
  lsr tmp + 1
  ror tmp
  lsr tmp + 1
  ror tmp
  ; Assume that everything is fine and save the sprite position
  lda tmp
  sta spriteX1
  ; Check if we are moving left or right (negative or positive respectively)
  lda velocityX1
  bmi @negative
@positive:
  lda spriteX1
  cmp #228
  bcs @not_hitright
  rts
@not_hitright:
  lda #$FC
  sta velocityX1
  lda #$FE
  sta velocityY1
  rts
@negative:
  lda spriteX1
  cmp #3
  bcc @not_hitleft
  rts
@not_hitleft:
  lda #$04
  sta velocityX1
  lda #$FE
  sta velocityY1
  rts
.endproc

; ------------------------------------------------------------------------------
; Update Gull1 sprite graphics and position in OAM
; ------------------------------------------------------------------------------
.proc sprite1_update
  jsr update_motion_state1
  jsr update_animation_frame1
  jsr update_heading1
  jsr update_sprite_tiles1
  jsr update_sprite_position1
  rts
.endproc

; ------------------------------------------------------------------------------
; Update motion state based on Y velocity
; ------------------------------------------------------------------------------
.proc update_motion_state1
  lda velocityY1
  bpl @fall
  lda #MotionState_FlyUp1
  sta motionState1
  rts
@fall:
  lda #MotionState_Fall1
  sta motionState1
  rts
.endproc

; ------------------------------------------------------------------------------
; Update animation frame based on velocity and timer
; ------------------------------------------------------------------------------
.proc update_animation_frame1
  lda animationTimer1
  bne @moving
  lda delay_by_velocity
  sta animationTimer1
@moving:
  dec animationTimer1
  beq @next_frame
  rts
@next_frame:
  ldx velocityX1
  bpl @update_frame
  lda #0
  sec
  sbc velocityX1
  tax
@update_frame:
  ldy animationFrame1
  iny
  cpy #4
  bne @transition_state
  ldy #0
@transition_state:
  sty animationFrame1
  lda delay_by_velocity, x
  sta animationTimer1
  rts
.endproc

; ------------------------------------------------------------------------------
; Update heading and sprite mirroring based on X velocity
; ------------------------------------------------------------------------------
.proc update_heading1
  lda velocityX1
  asl
  lda #0
  rol
  cmp heading1
  bne @update_heading
  rts
@update_heading:
  ; If the desired heading is not equal to the current heading based on the
  ; target velocity, then update the heading.
  sta heading1
  ; Toggle the "horizontal" mirroring on the character sprites
  lda #%01000000
  eor $200 + OAM_ATTR
  sta $200 + OAM_ATTR
  sta $204 + OAM_ATTR
  sta $208 + OAM_ATTR
  rts
.endproc

; ------------------------------------------------------------------------------
; Update sprite tiles based on motion state and animation frame
; ------------------------------------------------------------------------------
.proc update_sprite_tiles1
  lda motionState1
  cmp #MotionState_Fall1
  beq @fall
@fly_up:
  lda animationFrame1
  asl
  asl
  asl
  clc
  adc heading1
  tax
  lda fly_up_tiles, x
  sta $200 + OAM_TILE
  lda fly_up_tiles + 2, x
  sta $204 + OAM_TILE
  lda fly_up_tiles + 4, x
  sta $208 + OAM_TILE
  rts
@fall:
  lda #0
  clc
  adc heading1
  tax
  lda fall_tiles, x
  sta $200 + OAM_TILE
  lda fall_tiles + 2, x
  sta $204 + OAM_TILE
  lda fall_tiles + 4, x
  sta $208 + OAM_TILE
  rts
.endproc

; ------------------------------------------------------------------------------
; Update sprite position in OAM
; ------------------------------------------------------------------------------
.proc update_sprite_position1
  ; This is computed in `bound_position` above, so all we have to do is set
  ; the sprite coordinates appropriately.
  lda spriteX1
  sta $200 + OAM_X
  clc
  adc #8
  sta $204 + OAM_X
  adc #8
  sta $208 + OAM_X
  lda spriteY1
  sta $200
  sta $204
  sta $208
  rts
.endproc

; ==============================================================================
; Sprite2 (Gull2) State (Movement, Animation, etc.)
; ==============================================================================
.segment "ZEROPAGE"
velocityX2:              .res 1 ; Signed Fixed Point 4.4
positionX2:              .res 2 ; Signed Fixed Point 12.4
spriteX2:                .res 1 ; Unsigned Screen Coordinates
heading2:                .res 1 ; See `.enum Heading`, below...

velocityY2:              .res 1 ; Signed Fixed Point 4.4
positionY2:              .res 2 ; Signed Fixed Point 12.4
spriteY2:                .res 1 ; Unsigned Screen Coordinates

motionState2:            .res 1 ; See `.enum MotionState`, below...
animationFrame2:         .res 1 ; Current animation frame index
animationTimer2:         .res 1 ; Timer for animation frame updates

; ------------------------------------------------------------------------------
; Processing subroutine Sprite2 (Gull2) (Movement, Animation, etc.)
; ------------------------------------------------------------------------------
.segment "CODE"
spriteX_init2 = 199
velocityX_init2 = 252
positionX_LO_init2 = $70
positionX_HI_init2 = $0C

spriteY_init2 = 120
velocityY_init2 = 2
positionY_LO_init2 = $80
positionY_HI_init2 = $07

MotionState_FlyUp2 = 0
MotionState_Fall2  = 1

; ------------------------------------------------------------------------------
; Initialize Gull2 sprite state
; ------------------------------------------------------------------------------
.proc play_gull2_init
  jsr init_x2
  jsr init_y2
  jsr init_sprite_gull2
  rts
.endproc

; ------------------------------------------------------------------------------
; Initialize X position and velocity
; ------------------------------------------------------------------------------
.proc init_x2
  ; Set the initial x-position to 7 ($0070 in 12.4 fixed point)
  lda #spriteX_init2
  sta spriteX2
  lda #positionX_LO_init2
  sta positionX2
  lda #positionX_HI_init2
  sta positionX2 + 1
  ; Initialize the velocity
  lda #velocityX_init2
  sta velocityX2
  rts
.endproc

; ------------------------------------------------------------------------------
; Initialize Y position and velocity
; ------------------------------------------------------------------------------
.proc init_y2
  ; Set the initial y-position to 7 ($0800 in 12.4 fixed point)
  lda #spriteY_init2
  sta spriteY2
  lda #positionY_LO_init2
  sta positionY2
  lda #positionY_HI_init2
  sta positionY2 + 1
  ; Initialize the velocity
  lda #velocityY_init2
  sta velocityY2
  rts
.endproc

; ------------------------------------------------------------------------------
; Initialize Gull2 sprite graphics in OAM
; ------------------------------------------------------------------------------
.proc init_sprite_gull2
  NUM_SPRITES2 = 3
  LEFT_TILE2 = $21
  CENTER_TILE2 = $22
  RIGHT_TILE2 = $23
  ATTRS2 = %00000010
  ldx #0
@loop:
  lda initial_sprite_gull2, x
  sta $20C, x
  inx
  cpx #(4 * NUM_SPRITES2)
  bne @loop
  rts
initial_sprite_gull2:
  .byte spriteY_init2, LEFT_TILE2, ATTRS2, spriteX_init2
  .byte spriteY_init2, CENTER_TILE2, ATTRS2, spriteX_init2 + 8
  .byte spriteY_init2, RIGHT_TILE2, ATTRS2, spriteX_init2 + 16
.endproc

; ------------------------------------------------------------------------------
; Update Gull2 sprite state
; ------------------------------------------------------------------------------
.proc gull2_update
  jsr apply_velocity_y2
  jsr apply_velocity_x2
  jsr bound_position_y2
  jsr bound_position_x2
  jsr sprite2_update
  rts
.endproc

; ------------------------------------------------------------------------------
; Apply Y velocity to position
; ------------------------------------------------------------------------------
.proc apply_velocity_y2
  ; Check to see if we're moving to the down (positive) or the up (negative)
  lda velocityY2
  bmi @negative
@positive:
  ; Positive velocity is easy: just add the 4.4 fixed point velocity to the
  ; 12.4 fixed point position.
  clc
  adc positionY2
  sta positionY2
  lda #0
  adc positionY2 + 1
  sta positionY2 + 1
  rts
@negative:
  lda #0
  sec
  sbc velocityY2
  sta tmp
  lda positionY2
  sec
  sbc tmp
  sta positionY2
  lda positionY2 + 1
  sbc #0
  sta positionY2 + 1
  rts
.endproc

; ------------------------------------------------------------------------------
; Apply X velocity to position
; ------------------------------------------------------------------------------
.proc apply_velocity_x2
  ; Check to see if we're moving to the right (positive) or the left (negative)
  lda velocityX2
  bmi @negative
@positive:
  ; Positive velocity is easy: just add the 4.4 fixed point velocity to the
  ; 12.4 fixed point position.
  clc
  adc positionX2
  sta positionX2
  lda #0
  adc positionX2 + 1
  sta positionX2 + 1
  rts
@negative:
  lda #0
  sec
  sbc velocityX2
  sta tmp
  lda positionX2
  sec
  sbc tmp
  sta positionX2
  lda positionX2 + 1
  sbc #0
  sta positionX2 + 1
  rts
.endproc

; ------------------------------------------------------------------------------
; Bound Y position within screen limits
; ------------------------------------------------------------------------------
.proc bound_position_y2
  ; Convert the fixed point position coordinate into screen coordinates
  lda positionY2
  sta tmp
  lda positionY2 + 1
  sta tmp + 1
  lsr tmp + 1
  ror tmp
  lsr tmp + 1
  ror tmp
  lsr tmp + 1
  ror tmp
  lsr tmp + 1
  ror tmp
  ; Assume that everything is fine and save the sprite position
  lda tmp
  sta spriteY2
  ; Check if we are moving up or down (negative or positive respectively)
  lda velocityY2
  bmi @negative
@positive:
  lda spriteY2
  cmp #140
  bcs @not_hitbottom
  rts
@not_hitbottom:
  lda #$FE
  sta velocityY2
  rts
@negative:
  lda spriteY2
  cmp #7
  bcc @not_hittop
  rts
@not_hittop:
  lda #$03
  sta velocityY2
  lda velocityX2
  bmi @left
  lda #$FA
  sta velocityX2
  rts
@left:
  lda #$06
  sta velocityX2
  rts
.endproc

; ------------------------------------------------------------------------------
; Bound X position within screen limits
; ------------------------------------------------------------------------------
.proc bound_position_x2
  ; Convert the fixed point position coordinate into screen coordinates
  lda positionX2
  sta tmp
  lda positionX2 + 1
  sta tmp + 1
  lsr tmp + 1
  ror tmp
  lsr tmp + 1
  ror tmp
  lsr tmp + 1
  ror tmp
  lsr tmp + 1
  ror tmp
  ; Assume that everything is fine and save the sprite position
  lda tmp
  sta spriteX2
  ; Check if we are moving left or right (negative or positive respectively)
  lda velocityX2
  bmi @negative
@positive:
  lda spriteX2
  cmp #224
  bcs @not_hitright
  rts
@not_hitright:
  lda #$FC
  sta velocityX2
  rts
@negative:
  lda spriteX2
  cmp #7
  bcc @not_hitleft
  rts
@not_hitleft:
  lda #$04
  sta velocityX2
  rts
.endproc

; ------------------------------------------------------------------------------
; Update Gull2 sprite graphics and position in OAM
; ------------------------------------------------------------------------------
.proc sprite2_update
  jsr update_motion_state2
  jsr update_animation_frame2
  jsr update_heading2
  jsr update_sprite_tiles2
  jsr update_sprite_position2
  rts
.endproc

; ------------------------------------------------------------------------------
; Update motion state based on Y velocity
; ------------------------------------------------------------------------------
.proc update_motion_state2
  lda velocityY2
  bpl @fall
  lda #MotionState_FlyUp2
  sta motionState2
  rts
@fall:
  lda #MotionState_Fall2
  sta motionState2
  rts
.endproc

; ------------------------------------------------------------------------------
; Update animation frame based on velocity and timer
; ------------------------------------------------------------------------------
.proc update_animation_frame2
  lda animationTimer2
  bne @moving
  lda delay_by_velocity
  sta animationTimer2
@moving:
  dec animationTimer2
  beq @next_frame
  rts
@next_frame:
  ldx velocityX2
  bpl @update_frame
  lda #0
  sec
  sbc velocityX2
  tax
@update_frame:
  ldy animationFrame2
  iny
  cpy #4
  bne @transition_state
  ldy #0
@transition_state:
  sty animationFrame2
  lda delay_by_velocity, x
  sta animationTimer2
  rts
.endproc

; ------------------------------------------------------------------------------
; Update heading and sprite mirroring based on X velocity
; ------------------------------------------------------------------------------
.proc update_heading2
  lda velocityX2
  asl
  lda #0
  rol
  cmp heading2
  bne @update_heading
  rts
@update_heading:
  ; If the desired heading is not equal to the current heading based on the
  ; target velocity, then update the heading.
  sta heading2
  ; Toggle the "horizontal" mirroring on the character sprites
  lda #%01000000
  eor $20C + OAM_ATTR
  sta $20C + OAM_ATTR
  sta $210 + OAM_ATTR
  sta $214 + OAM_ATTR
  rts
.endproc

; ------------------------------------------------------------------------------
; Update sprite tiles based on motion state and animation frame
; ------------------------------------------------------------------------------
.proc update_sprite_tiles2
  lda motionState2
  cmp #MotionState_Fall2
  beq @fall
@fly_up:
  lda animationFrame2
  asl
  asl
  asl
  clc
  adc heading2
  tax
  lda fly_up_tiles, x
  sta $20C + OAM_TILE
  lda fly_up_tiles + 2, x
  sta $210 + OAM_TILE
  lda fly_up_tiles + 4, x
  sta $214 + OAM_TILE
  rts
@fall:
  lda #0
  clc
  adc heading2
  tax
  lda fall_tiles, x
  sta $20C + OAM_TILE
  lda fall_tiles + 2, x
  sta $210 + OAM_TILE
  lda fall_tiles + 4, x
  sta $214 + OAM_TILE
  rts
.endproc

; ------------------------------------------------------------------------------
; Update sprite position in OAM
; ------------------------------------------------------------------------------
.proc update_sprite_position2
  ; This is computed in `bound_position` above, so all we have to do is set
  ; the sprite coordinates appropriately.
  lda spriteX2
  sta $20C + OAM_X
  clc
  adc #8
  sta $210 + OAM_X
  adc #8
  sta $214 + OAM_X
  lda spriteY2
  sta $20C
  sta $210
  sta $214
  rts
.endproc

; ==============================================================================
; Sprite3 (Bonfire) State (Animation, etc.)
; ==============================================================================
.segment "ZEROPAGE"
animationFrame_bonfire:         .res 1 ; Current animation frame index
animationTimer_bonfire:         .res 1 ; Timer for animation frame updates
motionState_bonfire:            .res 1

; ------------------------------------------------------------------------------
; Processing subroutine Sprite3 (Bonfire) (Animation, etc.)
; ------------------------------------------------------------------------------
.segment "CODE"
MotionState_bonfire_off = 0
MotionState_bonfire_on  = 1

; ------------------------------------------------------------------------------
; Update Bonfire sprite state
; ------------------------------------------------------------------------------
.proc bonfire_update
  lda motionState_bonfire
  bne @begin
  rts
@begin:
  jsr update_animation_bonfire
  jsr update_sprite_bonfire
  rts
.endproc

; ------------------------------------------------------------------------------
; Update Bonfire animation frame based on timer
; ------------------------------------------------------------------------------
.proc update_animation_bonfire
  lda animationTimer_bonfire
  bne @animation
  lda delay_by_velocity
  sta animationTimer_bonfire
@animation:
  dec animationTimer_bonfire
  beq @update_frame
  rts
@update_frame:
  ldx #21 ; Fixed delay for bonfire animation
  lda delay_by_velocity, x
  sta animationTimer_bonfire
  lda #1
  eor animationFrame_bonfire
  sta animationFrame_bonfire
  rts
.endproc

; ------------------------------------------------------------------------------
; Update Bonfire sprite tiles in OAM
; ------------------------------------------------------------------------------
.proc update_sprite_bonfire
  lda animationFrame_bonfire
  tax
  lda bonfire_tiles, x
  sta $2F0 + OAM_TILE
  lda bonfire_tiles + 2, x
  sta $2F4 + OAM_TILE
  lda bonfire_tiles + 4, x
  sta $2F8 + OAM_TILE
  lda bonfire_tiles + 6, x
  sta $2FC + OAM_TILE
  rts
.endproc

; ------------------------------------------------------------------------------
; Enable Bonfire sprite
; ------------------------------------------------------------------------------
.proc EnableBonfire
  pha ; save current register values
  txa
  pha
  lda #MotionState_bonfire_on
  sta motionState_bonfire
  NUM_SPRITES_BONFIRE = 4
  TILE1_BONFIRE = $2B
  TILE2_BONFIRE = $2C
  TILE3_BONFIRE = $1B
  TILE4_BONFIRE = $1C
  ATTRS_BONFIRE = %00000000
  ldx #0
@loop:
  lda initial_sprite_bonfire, x
  sta $2F0, x
  inx
  cpx #(4 * NUM_SPRITES_BONFIRE)
  bne @loop
  pla ; restore register values
  tax
  pla
  rts

initial_sprite_bonfire:
  .byte 199, TILE1_BONFIRE, ATTRS_BONFIRE, 137
  .byte 199, TILE2_BONFIRE, ATTRS_BONFIRE, 145
  .byte 191, TILE3_BONFIRE, ATTRS_BONFIRE, 137
  .byte 191, TILE4_BONFIRE, ATTRS_BONFIRE, 145
.endproc

; ------------------------------------------------------------------------------
; Disable Bonfire sprite
; ------------------------------------------------------------------------------
.proc DisableBonfire
  pha ; save current register values
  txa
  pha
  lda #MotionState_bonfire_off
  sta motionState_bonfire
  ldx #16
  lda #$EF
@sprite_reset_loop:
  dex
  sta $2F0, x
  bne @sprite_reset_loop
  pla ; restore register values
  tax
  pla
  rts
.endproc

; ==============================================================================
; Sprite4 (Star) State (Movement, Animation, etc.)
; ==============================================================================
.segment "ZEROPAGE"
motionState_star:             .res 1 ; See `.enum MotionState`, below...
positionX_star:               .res 1 ; Unsigned Screen Coordinates x
positionY_star:               .res 1 ; Unsigned Screen Coordinates y
velocityX_star:               .res 1 ; Unsigned velocity x
velocityY_star:               .res 1 ; Unsigned velocity y
timerStar:                    .res 1 ; Timer for Star movement

; ------------------------------------------------------------------------------
; Processing subroutine Sprite4 (Star) (Movement, Animation, etc.)
; ------------------------------------------------------------------------------
.segment "CODE"
TILE_STAR = $49
ATTRS_STAR = %00000011
MotionState_star_off = 0
MotionState_star_on  = 1

; ------------------------------------------------------------------------------
; Enable Star sprite
; ------------------------------------------------------------------------------
.proc EnableStar
  pha ; save current register values
  tya
  pha
  txa
  pha
  jsr random
  ora #%01110000
  and #%01111111
  sta timerStar
  lda #MotionState_star_on
  sta motionState_star
  jsr set_position
  pla ; restore register values
  tax
  pla
  tay
  pla
  rts
.endproc

; ------------------------------------------------------------------------------
; Disable Star sprite
; ------------------------------------------------------------------------------
.proc DisableStar
  pha ; save current register values
  tya
  pha
  txa
  pha
  lda #MotionState_star_off
  sta motionState_star
  ldx #4
  lda #$EF
@sprite_reset_loop:
  dex
  sta $2EC, x
  bne @sprite_reset_loop
  pla ; restore register values
  tax
  pla
  tay
  pla
  rts
.endproc

; ------------------------------------------------------------------------------
; Star sprite positioning and boundary physics setup
; ------------------------------------------------------------------------------
.proc set_position
  jsr random            ; Generate a random X-coordinate in Accumulator (A)
  sta positionX_star    ; Store it as the initial X position of the star

  ldx #4                ; Set default horizontal velocity (moving right)
  stx velocityX_star    ; Save X velocity
  lda #3                ; Set default vertical velocity (moving down)
  sta velocityY_star    ; Save Y velocity

  lda positionX_star    ; Reload X position to check screen boundaries
  cmp #8                ; Check if X coordinate is less than 8
  bcc @setup_y_random   ; If X < 8, assign a randomized Y position
  cmp #72               ; Check if X coordinate is less than 72
  bcc @setup_y          ; If 8 <= X < 72, clear Y position to 0
  cmp #176              ; Check if X coordinate is less than 176
  bcc @disablestar      ; If 72 <= X < 176, hide/disable this star
  
  ldx #$FC              ; Set reverse horizontal velocity (-4 in two's complement)
  stx velocityX_star    ; Save X velocity (moving left)
  
  cmp #248              ; Check if X coordinate is out of bounds on the right edge
  bcs @setup_y_random   ; If X >= 248, assign a randomized Y position

@setup_y:
  ; Optimization: A is guaranteed to be 0 here if branched from 'bcc @setup_y'
  ldx #0
  stx positionY_star    ; Set Y position to 0 (top of screen boundary)
  rts                   ; Return from subroutine

@setup_y_random:
  jsr random            ; Generate a new random number for the vertical axis
  and #%00011111        ; Mask out high bits to constrain Y within a 32-pixel range
  sta positionY_star    ; Save the randomized Y coordinate
  rts                   ; Return from subroutine

@disablestar:
  jmp DisableStar       ; Tail-Call Optimization: Directly jump to save stack space
  rts
.endproc

; ------------------------------------------------------------------------------
; Update Star sprite state
; ------------------------------------------------------------------------------
.proc star_update
  lda motionState_star
  bne @begin
  rts
@begin:
  lda timeFrame
  cmp timerStar
  bcs :+
  rts
: lda positionY_star
  sta $2EC + OAM_Y
  lda #TILE_STAR
  sta $2EC + OAM_TILE
  lda #ATTRS_STAR
  sta $2EC + OAM_ATTR
  lda positionX_star
  sta $2EC + OAM_X
  ; set coordinates x
  lda positionX_star
  clc
  adc velocityX_star
  cmp #8
  bcs @not_hitleft
  jsr DisableStar
  rts
@not_hitleft:
  cmp #252
  bcc @not_hitright
  jsr DisableStar
  rts
@not_hitright:
  sta positionX_star
  ; set coordinates y
  lda positionY_star
  clc
  adc velocityY_star
  cmp #145
  bcc @not_hitbottom
  jsr DisableStar
  rts
@not_hitbottom:
  sta positionY_star
  rts
.endproc

; ==============================================================================
; Sprite5 (Cursor) State (Movement, Animation, etc.)
; ==============================================================================
.segment "ZEROPAGE"
spriteX_cursor:                .res 1 ; Unsigned Screen Coordinates x
spriteY_cursor:                .res 1 ; Unsigned Screen Coordinates y
heading_cursor:                .res 1 ; See `.enum Heading`, below...

motionState_cursor:            .res 1 ; See `.enum MotionState`, below...
animationFrame_cursor:         .res 1 ; Current animation frame index
animationTimer_cursor:         .res 1 ; Timer for animation frame updates

switch_cursor:                 .res 1 ; Switch to turn cursor on/off

; ------------------------------------------------------------------------------
; Processing subroutine Sprite5 (Cursor) (Movement, Animation, etc.)
; ------------------------------------------------------------------------------
.segment "CODE"
spriteX_Cursor_init = 16
spriteY_Cursor_init = 16

MotionState_FlyUp_Cursor = 0
MotionState_Fall_Cursor  = 1

Switch_cursor_off = 0
Switch_cursor_on  = 1

; ------------------------------------------------------------------------------
; Initialize Cursor sprite state
; ------------------------------------------------------------------------------
.proc set_cursor_init
  jsr set_cursor_target
  jsr init_sprite_cursor
  rts
.endproc

; ==============================================================================
; Initialize Cursor sprite target
; ==============================================================================
.proc set_cursor_target
  ; set cursor targets depending on selected game number
  ; left cursor, X
  lda #(game_names_offset - 2) * 8
  sta spriteX_cursor
  ; Y coordinate
  lda selected_game
  sec
  sbc text_lines_target
  clc
  adc #top_name_offset
  asl A
  asl A
  asl A
  sta spriteY_cursor
  ; Check for top of screen
  cmp #top_name_offset * 8
  bcs @check_bottom
  lda #top_name_offset * 8
  clc
  adc #(lines_per_screen - 1) * 8
  sta spriteY_cursor
  lda text_lines_target
  sec
  sbc #lines_per_screen
  sta text_lines_target
  lda text_lines_target + 1
  sbc #0
  sta text_lines_target + 1
  jmp @off_write_header
  
  ; Check for bottom of screen
@check_bottom:
  cmp #(top_name_offset * 8) + (lines_per_screen * 8)
  bcc @end
  lda #top_name_offset * 8
  sta spriteY_cursor
  lda #lines_per_screen
  clc
  adc text_lines_target
  sta text_lines_target
  lda text_lines_target + 1
  adc #0
  sta text_lines_target + 1

@off_write_header:
  lda #0
  sta ready_write_header
@end:
  rts
.endproc

; ==============================================================================
; Initialize Cursor sprite graphics in OAM
; ==============================================================================
.proc init_sprite_cursor
  NUM_SPRITES1_CURSOR = 2
  LEFT_TILE_CURSOR = $41
  RIGHT_TILE_CURSOR = $42
  ATTRS_CURSOR = %00000001 ; Palette 1
  ; Only initialize if the cursor is enabled
  lda #Switch_cursor_on ; This is the line for turning the cursor on and off б use witch_cursor_on or witch_cursor_off. 
  sta switch_cursor
  cmp #Switch_cursor_off
  beq @end
  ; Initialize the cursor sprites in OAM
  ldx #0
@loop:
  lda initial_sprite_cursor, x
  sta $218, x
  inx
  cpx #(4 * NUM_SPRITES1_CURSOR)
  bne @loop
@end:
  rts
initial_sprite_cursor:
  .byte spriteY_cursor, LEFT_TILE_CURSOR, ATTRS_CURSOR, spriteX_cursor
  .byte spriteY_cursor, RIGHT_TILE_CURSOR, ATTRS_CURSOR, spriteX_cursor + 8
.endproc

; ==============================================================================
; Update Cursor state each frame
; ==============================================================================
.proc cursor_update
  ; Check for button presses and update the cursor state accordingly
  ; RIGHT
  lda #1
  sta scroll_dir
  lda #BUTTON_RIGHT
  sta scroll_button_mask
  jsr scroll_page
  ; LEFT
  lda #$FF
  sta scroll_dir
  lda #BUTTON_LEFT
  sta scroll_button_mask
  jsr scroll_page
  ; DOWN
  lda #1
  sta cursor_dir
  lda #BUTTON_DOWN
  sta cursor_button_mask
  jsr move_cursor
  ; UP
  lda #$FF
  sta cursor_dir
  lda #BUTTON_UP
  sta cursor_button_mask
  jsr move_cursor
  ; Update the cursor sprite graphics and position in OAM
  jsr sprite_cursor_update
  rts
.endproc

; ==============================================================================
; Update Cursor sprite graphics and position in OAM
; ==============================================================================
.proc sprite_cursor_update
  ; Only update if the cursor is enabled
  lda switch_cursor
  cmp #Switch_cursor_off
  beq @end
  ; Update motion state, animation frame, heading, sprite tiles, and position
  jsr update_motion_state_cursor
  jsr update_animation_frame_cursor
  jsr update_sprite_tiles_cursor
  jsr update_sprite_position_cursor
@end:
  rts
.endproc

; ==============================================================================
; Update motion state based on Y velocity
; ==============================================================================
.proc update_motion_state_cursor
  lda buttons
  and #BUTTON_DOWN
  bne @fall
  lda #MotionState_FlyUp_Cursor
  sta motionState_cursor
  rts
@fall:
  lda #MotionState_Fall_Cursor
  sta motionState_cursor
@end:
  rts
.endproc

; ==============================================================================
; Update animation frame based on velocity and timer
; ==============================================================================
.proc update_animation_frame_cursor
  lda animationTimer_cursor
  bne @animation
  lda delay_by_velocity
  sta animationTimer_cursor
@animation:
  dec animationTimer_cursor
  beq @update_frame
  rts
@update_frame:
  ldx #6  ; Fixed delay for cursor animation
  ldy animationFrame_cursor
  iny
  cpy #4
  bne @transition_state
  ldy #0
@transition_state:
  sty animationFrame_cursor
  lda delay_by_velocity, x
  sta animationTimer_cursor
  rts
.endproc

; ==============================================================================
; Update sprite tiles based on motion state and animation frame
; ==============================================================================
.proc update_sprite_tiles_cursor
  lda motionState_cursor
  cmp #MotionState_Fall_Cursor
  beq @fall
@fly_up:
  lda animationFrame_cursor
  asl A
  asl A
  clc
  adc heading_cursor
  tax
  lda fly_up_tiles_cursor, x
  sta $218 + OAM_TILE
  lda fly_up_tiles_cursor + 2, x
  sta $21C + OAM_TILE
  rts
@fall:
  lda #0
  clc
  adc heading_cursor
  tax
  lda fall_tiles_cursor, x
  sta $218 + OAM_TILE
  lda fall_tiles_cursor + 2, x
  sta $21C + OAM_TILE
  rts
.endproc

; ==============================================================================
; Update sprite position in OAM
; ==============================================================================
.proc update_sprite_position_cursor
  lda spriteX_cursor
  sta $218 + OAM_X
  clc
  adc #8
  sta $21C + OAM_X
  lda spriteY_cursor
  sta $218 + OAM_Y
  sta $21C + OAM_Y
  rts
.endproc