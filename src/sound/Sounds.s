;*****************************************************************
; Include Sound Engine, Sound Effects and Music Data
;*****************************************************************

.segment "CODE"
; FamiStudio config.
FAMISTUDIO_CFG_EXTERNAL       = 1
FAMISTUDIO_CFG_DPCM_SUPPORT   = 1
FAMISTUDIO_CFG_SFX_SUPPORT    = 1 
FAMISTUDIO_CFG_SFX_STREAMS    = 2
FAMISTUDIO_CFG_EQUALIZER      = 1
FAMISTUDIO_USE_VOLUME_TRACK   = 1
FAMISTUDIO_USE_PITCH_TRACK    = 1
FAMISTUDIO_USE_SLIDE_NOTES    = 1
FAMISTUDIO_USE_VIBRATO        = 1
FAMISTUDIO_USE_ARPEGGIO       = 1
FAMISTUDIO_CFG_SMOOTH_VIBRATO = 1
FAMISTUDIO_USE_RELEASE_NOTES  = 1
FAMISTUDIO_DPCM_OFF           = $e000

; CA65-specifc config.
.define FAMISTUDIO_CA65_ZP_SEGMENT   ZEROPAGE
.define FAMISTUDIO_CA65_RAM_SEGMENT  BSS
.define FAMISTUDIO_CA65_CODE_SEGMENT CODE

.include "SoundEngine/famistudio_ca65.s"
.include "song.s"
.include "sfx.s"

; Initialize Sound Engine
.proc sound_init
  ;------------------------------------------------------------------------------
  ; reset APU, initialize FamiStudio
  ; [in] a : Playback platform, zero for PAL, non-zero for NTSC.
  ; [in] x : Pointer to music data (lo)
  ; [in] y : Pointer to music data (hi)
  ;------------------------------------------------------------------------------
  lda #1 ; NTSC 
  ldx #.lobyte(music_data_10000000_in_1_menu)
  ldy #.hibyte(music_data_10000000_in_1_menu)
  jsr famistudio_init

  ;------------------------------------------------------------------------------
  ; Initialize the sound effect player.
  ; [in] x: Sound effect data pointer (lo)
  ; [in] y: Sound effect data pointer (hi)
  ;------------------------------------------------------------------------------
  ldx #.lobyte(sounds)             ; set address of sound effects
  ldy #.hibyte(sounds)
  jsr famistudio_sfx_init
  rts
.endproc

;------------------------------------------------------------------------------
; Plays a sound effect.
; [in] a: Sound effect index (0...127)
; [in] x: Offset of sound effect channel, should be FAMISTUDIO_SFX_CH0..FAMISTUDIO_SFX_CH3
;------------------------------------------------------------------------------
.proc play_sfx
  ldx #FAMISTUDIO_SFX_CH0      ; choose the channel to play the sound effect on
  jsr famistudio_sfx_play
  rts
.endproc

.proc play_sfx_without_NMI
  ; Load and trigger the sound effect (pushes data into the engine buffer)
  ldx #FAMISTUDIO_SFX_CH0      ; choose the channel to play the sound effect on
  jsr famistudio_sfx_play      ; Fire the sound effect!

@WaitLoop:
  ; Manual frame synchronization (Replaces the automatic NMI trigger)
  VblankWait
  
  ; Manually advance the sound engine by exactly one audio frame (~1/60th of a second)
  jsr famistudio_update

  ; FIX: Check if FamiTone2 finished processing this sound channel
  ; We check the internal engine repeat counter for Channel 0
  lda famistudio_sfx_repeat+0 ; Read internal sound counter
  bne @WaitLoop       ; If any channel is NOT zero, the sound is still playing. Loop.

  ; HARDWARE FIX: Force silence all basic registers so the last note never hangs!
  lda #$30            ; Zero volume flag for Square channels
  sta PULSE1_CTRL     ; Mute Pulse 1
  sta PULSE2_CTRL     ; Mute Pulse 2
  lda #$00
  sta TRI_LINEAR      ; Mute Triangle (Linear counter to 0)
  lda #$30
  sta NOISE_CTRL      ; Mute Noise

  rts                 ; Safely exit back to the game!
.endproc

.proc reset_sound
  ; --- Initialize Audio Processing Unit (APU) Hardware Registers ---
  lda #0             ; Load Accumulator with 0
  sta PULSE1_CTRL    ; Silence Pulse 1 volume envelope controls
  sta PULSE1_SWEEP   ; Clear Pulse 1 pitch sweeping register configurations
  sta PULSE1_PERIOD  ; Clear Pulse 1 low frequency timer byte 
  sta PULSE1_LEN     ; Reset Pulse 1 high frequency bits and active duration trackers
  sta PULSE2_CTRL    ; Silence Pulse 2 volume envelope controls
  sta PULSE2_SWEEP   ; Clear Pulse 2 pitch sweeping register configurations
  sta PULSE2_PERIOD  ; Clear Pulse 2 low frequency timer byte
  sta PULSE2_LEN     ; Reset Pulse 2 high frequency bits and active duration trackers
  sta TRI_LINEAR     ; Zero out Triangle linear duration counter settings
  sta TRI_PERIOD     ; Clear Triangle channel low frequency timer byte
  sta TRI_LEN        ; Reset Triangle high frequency bits and active duration trackers
  sta NOISE_CTRL     ; Silence Noise channel audio volume envelopes
  sta NOISE_PERIOD   ; Clear Noise randomizer frequency playback speeds
  sta NOISE_LEN      ; Reset Noise duration track counter configurations
  sta DMC_CTRL       ; Clear Delta Modulation Channel configuration values
  sta DMC_DATA       ; Reset raw Direct Audio digital DAC level values
  sta DMC_ADDR       ; Clear pointers pointing to sample memory locations
  sta DMC_LEN        ; Reset lengths assigned to sample arrays
  lda #$40           ; Load A register with $40
  sta APUFRAME       ; Write $40 to APU frame counter register to disable APU frame IRQ signals
  rts
.endproc