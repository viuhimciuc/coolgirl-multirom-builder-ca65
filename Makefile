SRC_DIR =           src/
CONFIGS_DIR ?=      configs/
IMAGES_DIR =        images/

GAMES ?=            games.list
MENU_SYMBOLS ?=     menu_symbols.png
NAME ?=             $(basename $(notdir $(wildcard $(SRC_DIR)*.s)))
OBJ_FILES :=        $(addsuffix .o, $(NAME))

# for the Russian language, use rus
LANGUAGE ?=         eng
SIZE ?=             128
MAXCHRSIZE ?=       256

GAMES_DB =         $(GAMES)_$(LANGUAGE)
MENU_ROM ?=        menu_$(GAMES_DB)

OFFSETS ?=         offsets_$(GAMES_DB).json
OUTPUT_UNIF ?=     multirom_$(GAMES_DB).unf
OUTPUT_NES20 ?=    multirom_$(GAMES_DB).nes
OUTPUT_BIN ?=      multirom_$(GAMES_DB).bin

SYMBOL_FILES =     menu_symbols.bin

SOURCES =          src/$(NAME).s \
                   src/lib/ppu.s \
				   src/binary/$(SYMBOL_FILES) \
                   src/graphic/Screen.s src/graphic/dim.inc src/graphic/Sprites.s src/graphic/Tests.s src/graphic/Text.s \
                   src/device/Buildinfo.s src/device/Console.s src/device/input_handlers.inc src/device/Joypad.s \
                   src/memory/Banking.s src/memory/CopyToRam.s src/memory/Flash.s src/memory/Loader.s src/memory/Preloader.s src/memory/Saves.s \
                   src/sound/Sounds.s src/sound/song.s src/sound/sfx.s src/sound/SoundEngine/famistudio_ca65.s

# tools
EMU_MESEN =     Mesen
EMU_FCEUX =     fceux64
COMBINER =      ./tools/CoolgirlCombiner-ca65/coolgirl-combiner-ca65
TILER =         ./tools/nestiler/nestiler
COLORS =        ./tools/nestiler/nestiler-colors.json

CA65 =          ca65
LD65 =          ld65

CHECK_RUS_ENABLED ?= $(LANGUAGE)
ifeq ($(CHECK_RUS_ENABLED),rus)
CA65_OPTS += -D RUS_ENABLED=1
else
CA65_OPTS += -D RUS_ENABLED=0
endif

SAVES ?= 0
ifneq ($(SAVES),0)
SAVES_OPTION=--saves
endif

NOSORT ?= 1
ifneq ($(NOSORT),0)
SORT_OPTION=--nosort
endif

BADSECTORS ?= -1
ifneq ($(BADSECTORS),-1)
BADS_OPTION=--badsectors $(BADSECTORS)
endif

REPORT ?=
ifneq ($(REPORT),)
REPORT_OPTION=--report $(REPORT)
endif

# Time before button autorepeat
# Initial delay (30 frames)
BUTTON_REPEAT_DELAY ?= -1
ifneq ($(BUTTON_REPEAT_DELAY),-1)
CA65_OPTS += -D BUTTON_REPEAT_DELAY=$(BUTTON_REPEAT_DELAY)
endif
# Repeat every 10 frames
BUTTON_REPEAT_RATE ?= -1
ifneq ($(BUTTON_REPEAT_RATE),-1)
CA65_OPTS += -D BUTTON_REPEAT_RATE=$(BUTTON_REPEAT_RATE)
endif
# Remember last started game
ENABLE_LAST_GAME_SAVING ?= -1
ifneq ($(ENABLE_LAST_GAME_SAVING),-1)
CA65_OPTS += -D ENABLE_LAST_GAME_SAVING=$(ENABLE_LAST_GAME_SAVING)
endif
# Frame counter to control the speed of the transition dim
FADE_DELAY ?= -1
ifneq ($(FADE_DELAY),-1)
CA65_OPTS += -D FADE_DELAY=$(FADE_DELAY)
endif

LD65_OPTS += -m $(MENU_ROM).map.txt -Ln $(MENU_ROM).labels.txt

CA65-ARGS += $(NAME).s -g -D HEADER_ENABLED=0 $(CA65_OPTS)
LD65-ARGS += -C menu_no_header.cfg $(LD65_OPTS)

.PHONY: default build all nes20 nes unif bin menu run runmenu clean

default: nes20
build: nes20
all: nes20 unif bin

$(MENU_ROM): $(SYMBOL_FILES) $(SOURCES) $(GAMES_DB) $(OBJ_FILES)
	$(call build-file-nes)
	@echo ===================================================
	@echo SUCCESS! $(MENU_ROM).nes, map, and labels generated.
	@echo ===================================================

menu: $(MENU_ROM)

$(GAMES_DB) $(OFFSETS): $(CONFIGS_DIR)/$(GAMES)
	$(COMBINER) prepare --games $(CONFIGS_DIR)$(GAMES) --asm $(GAMES_DB).inc \
	--maxromsize $(SIZE) --maxchrsize $(MAXCHRSIZE) --sources $(SRC_DIR) --offsets $(SRC_DIR)$(OFFSETS) --language $(LANGUAGE) \
	$(REPORT_OPTION) $(SORT_OPTION) $(BADS_OPTION) $(SAVES_OPTION)

$(OUTPUT_NES20): OUT_FLAG = --nes20 $@
$(OUTPUT_UNIF):  OUT_FLAG = --unif $@
$(OUTPUT_BIN):   OUT_FLAG = --bin $@

#$(OUTPUT_NES20) $(OUTPUT_UNIF) $(OUTPUT_BIN): $(SYMBOL_FILES) $(SOURCES) $(MENU_ROM) $(OFFSETS)
#	$(COMBINER) combine --loader $(SRC_DIR)$(MENU_ROM).nes --offsets $(SRC_DIR)$(OFFSETS) $(OUT_FLAG)

$(OUTPUT_NES20) $(OUTPUT_UNIF) $(OUTPUT_BIN): $(SYMBOL_FILES) $(SOURCES) $(CONFIGS_DIR)$(GAMES)
	$(COMBINER) build --games $(CONFIGS_DIR)$(GAMES) --asm $(GAMES_DB).inc \
		--maxromsize $(SIZE) --maxchrsize $(MAXCHRSIZE) $(REPORT_OPTION) $(SORT_OPTION) $(BADS_OPTION) $(SAVES_OPTION) --language $(LANGUAGE) \
		--sources $(SRC_DIR) --ca65 $(CA65) --ca65-args "$(CA65-ARGS)" \
		--ld65 $(LD65) --ld65-args "$(LD65-ARGS)" $(OUT_FLAG)

nes20: $(OUTPUT_NES20)
nes: nes20
unif:  $(OUTPUT_UNIF)
bin:   $(OUTPUT_BIN)

define build-file-obj
	@clear || cls
	@echo ===================================================
	@echo               Compiling NES Project...             
	@echo ===================================================
	@echo "Assembling $(OBJ_FILES)..."
	ca65 $< -g -o $(SRC_DIR)$@ -D HEADER_ENABLED=1 $(CA65_OPTS)
endef

define build-file-nes
	@echo ""
	@echo "Assembly successful. Linking..."
	ld65 -o $(SRC_DIR)$(MENU_ROM).nes -C $(SRC_DIR)menu_header.cfg $(SRC_DIR)$(OBJ_FILES) -m $(SRC_DIR)$(MENU_ROM).map.txt -Ln $(SRC_DIR)$(MENU_ROM).labels.txt --dbgfile $(SRC_DIR)$(MENU_ROM).nes.dbg
endef

%.o: $(SRC_DIR)%.s
	$(call build-file-obj)

define text_run_emularot
	@echo ===================================================
	@echo Run Emulator...
	@echo ===================================================
endef

run: $(OUTPUT_NES20)
	$(call text_run_emularot)
	$(EMU_FCEUX) $(OUTPUT_NES20)

runmenu: $(MENU_ROM)
	$(call text_run_emularot)
	$(EMU_MESEN) $(SRC_DIR)$(MENU_ROM).nes

clean:
	@echo
	@echo Deleting ...
	rm -f $(SRC_DIR)*.nes $(SRC_DIR)*.o $(SRC_DIR)*.map.txt $(SRC_DIR)*.labels.txt $(SRC_DIR)*.dbg $(SRC_DIR)games.list* $(SRC_DIR)offsets*.json \
	*.txt *.deb *.unf *.nes *.bin $(SRC_DIR)binary/$(SYMBOL_FILES)

$(SYMBOL_FILES): $(IMAGES_DIR)$(MENU_SYMBOLS)
	$(TILER) --colors $(COLORS) \
		--i0 $(IMAGES_DIR)$(MENU_SYMBOLS) \
		--out-pattern-table0 $(SRC_DIR)binary/$(SYMBOL_FILES)