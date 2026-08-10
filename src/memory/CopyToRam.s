.segment "ZEROPAGE"
ptr_rom:    .res 2    ; Source address pointer in ROM
ptr_ram:    .res 2    ; Destination address pointer in RAM
bytes_left: .res 2    ; 16-bit counter for remaining bytes

.segment "CODE"
; Import automatic symbols from the linker for both segments
.import __RAM_ROUTINES_LOAD__, __RAM_ROUTINES_RUN__, __RAM_ROUTINES_SIZE__
.import __LOADER_CLEAN_LOAD__, __LOADER_CLEAN_RUN__, __LOADER_CLEAN_SIZE__

; ==============================================================================
; Copy_All_Loader_To_Ram
; Description: Safely copies the RAM_ROUTINES segment (handles sizes > 256 bytes)
;              to RAM starting at $0500, and then copies the LOADER_CLEAN segment
;              strictly to RAM address $07E0.
; ==============================================================================
.proc Copy_All_Loader_To_Ram
  ; --------------------------------------------------------------------------
  ; PART 1: Copy RAM_ROUTINES (Supports any size larger than 256 bytes)
  ; --------------------------------------------------------------------------
  ; 1. Initialize the source ROM pointer
  lda #<.loword(__RAM_ROUTINES_LOAD__)
  sta ptr_rom
  lda #>.loword(__RAM_ROUTINES_LOAD__)
  sta ptr_rom+1

  ; 2. Initialize the destination RAM pointer
  lda #<.loword(__RAM_ROUTINES_RUN__)
  sta ptr_ram
  lda #>.loword(__RAM_ROUTINES_RUN__)
  sta ptr_ram+1

  ; 3. Load the 16-bit total size of the segment
  lda #<.loword(__RAM_ROUTINES_SIZE__)
  sta bytes_left
  lda #>.loword(__RAM_ROUTINES_SIZE__)
  sta bytes_left+1

  ; If the size is somehow 0, skip the first part entirely
  lda bytes_left
  ora bytes_left+1
  beq @copy_clean_script

  ldy #0
@loop_routines:
  ; Copy a single byte using indirect indexed addressing
  lda (ptr_rom), y    
  sta (ptr_ram), y    

  ; Decrement the 16-bit bytes_left counter
  lda bytes_left
  bne @skip_high_dec
  dec bytes_left+1
@skip_high_dec:
  dec bytes_left

  ; Check if we finished copying all bytes (bytes_left == 0)
  lda bytes_left
  ora bytes_left+1
  beq @copy_clean_script

  ; Advance the index
  iny
  bne @loop_routines   ; Continue loop if Y hasn't wrapped around to 0

  ; Page crossing: increment the high bytes of pointers and reset Y to 0
  inc ptr_rom+1
  inc ptr_ram+1
  jmp @loop_routines

  ; --------------------------------------------------------------------------
  ; PART 2: Copy LOADER_CLEAN (Guaranteed to be under 256 bytes)
  ; --------------------------------------------------------------------------
@copy_clean_script:
  ldx #0
@loop_clean:
  lda __LOADER_CLEAN_LOAD__, x
  sta __LOADER_CLEAN_RUN__, x  ; Writes directly to RAM strictly at $07E0
  inx
  cpx #.lobyte(__LOADER_CLEAN_SIZE__)
  bne @loop_clean

  rts
.endproc