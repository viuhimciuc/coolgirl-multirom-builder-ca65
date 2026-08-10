; ============================================================
; Start_game
; Handles fade-out, PPU shutdown, Konami code override,
; compatibility checks, error screen, and transition to loader.
; ============================================================

.segment "CODE"
start_game:
  jsr famistudio_music_stop     ; Optional: wait for music to finish

  lda konami_code_state
  cmp konami_code_length
  beq @start_sound_alt
  lda #11                       ; Start sound
  jsr play_sfx                  ; Play sfx sound
  jmp @start_sound_end

@start_sound_alt:
  lda #13                       ; StartAlt sound
  jsr play_sfx                  ; Play sfx sound
@start_sound_end:

  ; in Palette_FadeOut Disable PPU, this must be done.
  lda #1
  jsr Palette_FadeOut           ; Fade screen out

  ; --------------------------------------------------------
  ; Konami code: if fully entered, override selected_game
  ; --------------------------------------------------------
.if SECRETS >= 3
  lda konami_code_state
  cmp konami_code_length
  bne @no_konami_code

  ; selected_game = GAMES_COUNT + 2
  lda #.lobyte(GAMES_COUNT)
  clc
  adc #2
  sta selected_game

  lda #.hibyte(GAMES_COUNT)
  adc #0
  sta selected_game + 1
@no_konami_code:
.endif

  ; --------------------------------------------------------
  ; Check console compatibility for selected game
  ; --------------------------------------------------------
  lda selected_game + 1
  select_prg_bank               ; Switch PRG bank

  ldx selected_game
  lda loader_data_game_flags, x
  and console_type
  bne @no_compatible            ; If incompatible → show error

  jmp compatible_console        ; Otherwise continue

; ------------------------------------------------------------
; Incompatible console branch
; ------------------------------------------------------------
@no_compatible:
  ; Not compatible console!
  lda #04                       ; Error sound
  jsr play_sfx                  ; Play sfx sound
  ; Save state, without game save
  lda #0
  sta last_started_save         ; No save slot used
  jsr save_state                ; Save global state

  ; --------------------------------------------------------
  ; Show incompatible console error screen
  ; --------------------------------------------------------
  ClearScreen NAMETABLE_A         ; Wipe the nametable for fresh rendering
  LoadNameTable NAMETABLE_A, $01
  LoadAttributes ATTR_A, $00      ; Load text attributes
  lda #1                          ; Select palette number: pscreen_1, "src/bin/palettes_screen_1.pal"
  jsr preload_palette             ; Load palettes from the second screen.

  Vram $21A0                      ; Set VRAM pointer for text
  lda #.lobyte(string_incompatible_console)
  sta copy_source_addr
  lda #.hibyte(string_incompatible_console)
  sta copy_source_addr+1
  jsr print_text

  lda #1
  jsr Palette_FadeIn              ; Fade screen in

; ------------------------------------------------------------
; Wait until all buttons released
; ------------------------------------------------------------
@incompatible_print_wait_no_button:
  jsr read_joypad1
  lda pressed
  bne @incompatible_print_wait_no_button

  ; Tiny delay (15 frames)
  ldx #15
@incompatible_wait:
  VblankWait
  dex
  bne @incompatible_wait

; ------------------------------------------------------------
; Wait until any button pressed
; ------------------------------------------------------------
@incompatible_print_wait_button:
  jsr read_joypad1
  lda pressed
  beq @incompatible_print_wait_button

  lda #1
  jsr Palette_FadeOut           ; Fade out before reset

  jmp reset                     ; Reset console

; ------------------------------------------------------------
; compatible_console
; Prepare PPU, CHR, OAM, registers, save data, and jump to loader
; ------------------------------------------------------------
compatible_console:
  ; Clear NTRAM
  enable_chr_write
  enable_four_screen
  ClearScreenAll                ; Clear all nametables

  disable_four_screen
  ClearScreenAll                ; Clear again (mapper-specific)
  disable_chr_write

  ; Clear OAM
  ClearSprites oam
  SpriteDMA oam                 ; Upload empty OAM

  ; --------------------------------------------------------
  ; Load game-specific registers and CHR settings
  ; --------------------------------------------------------
  ldx selected_game

  lda loader_data_reg_0, x
  sta loader_reg_0
  lda loader_data_reg_1, x
  sta loader_reg_1
  lda loader_data_reg_2, x
  sta loader_reg_2
  lda loader_data_reg_3, x
  sta loader_reg_3
  lda loader_data_reg_4, x
  sta loader_reg_4
  lda loader_data_reg_5, x
  sta loader_reg_5
  lda loader_data_reg_6, x
  sta loader_reg_6
  lda loader_data_reg_7, x
  sta loader_reg_7

  lda loader_data_chr_start_bank_h, x
  sta loader_chr_start_h
  lda loader_data_chr_start_bank_l, x
  sta loader_chr_start_l
  lda loader_data_chr_start_bank_s, x
  sta loader_chr_start_s

  lda loader_data_chr_count, x
  sta loader_chr_left

  lda loader_data_game_save, x
  sta loader_game_save
  sta last_started_save        ; Save ID

  lda #2
  sta loader_game_save_bank

  ; --------------------------------------------------------
  ; Load save data and persist state
  ; --------------------------------------------------------
  jsr load_save
  jsr save_state

  ; --------------------------------------------------------
  ; Load PRG and CHR banks, then jump to loader
  ; --------------------------------------------------------
  lda #0
  select_prg_bank             ; First PRG bank
  jsr load_all_chr_banks      ; Load all CHR tiles
  ;jsr reset_sound
  jmp loader                  ; Jump to RAM loader