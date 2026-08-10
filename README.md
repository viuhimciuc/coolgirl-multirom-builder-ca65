# 🛠️ COOLGIRL Multirom Builder based on ca65

This is a toolset created based on the project [COOLGIRL Multirom Builder](https://github.com/ClusterM/coolgirl-multirom-builder). It will help create MultiROM images with a classic "9999-in-1" pirate cartridge menu for [COOLGIRL Famicom cartridges](https://github.com/ClusterM/coolgirl-famicom-multicart) (mapper 342). The resulting ROM file can be run on an emulator or written to a cartridge.

![Loader menu](https://github.com/user-attachments/assets/82ab0e60-9423-4c8a-991c-c6b44c98eaf9)

## 🚀 Key Features

* **📦 Game Combination:** Automatically combine up to 1536 games into a single binary which can be written to a COOLGIRL cartridge.
* **🎨 Classic UI:** Create a nice classic "9999-in-1" pirate cartridge menu.
* **🔤 Smart Sorting:** Alphabetically sort games if needed.
* **🖌️ Customization:** Use your own symbol images in the menu.
* **💾 Save Management:** Remember the last played game and keep up to 255 saves for "battery-backed" games into flash memory.
* **🔬 Diagnostics:** Run built-in hardware tests.
* **ℹ️ Diagnostics Info:** Show build and hardware info.
* **🤫 Easter Eggs:** Add up to three hidden ROMs.
* **💻 Cross-Platform:** Run on Windows (x64), Linux (x64, ARM, ARM64), and macOS (x64).

⚠️ **Requirement:** .NET 6.0 is required. You need to either install the [.NET 6.0 Runtime](https://dotnet.microsoft.com/en-us/download/dotnet/6.0) or use the self-contained version.

## 💾 How to Build a ROM

This package contains multiple tools which need to run sequentially. There is a Makefile, so you can use the [Make](https://www.gnu.org/software/make/) tool to automate the whole process. This is the simplest way. Windows users can use [msys2](https://www.msys2.org/) to install and run Make.

But first, you need to install the cc65 cross-compiler suite (following the instructions at [cc65](https://cc65.github.io/getting-started.html#Windows)) and create a list of games, saving it in the "configs" directory.

### 📝 Game List Format

It's just a text file. Lines starting with a semicolon are comments. Other lines use the following format:

```text
<path_to_filename> [| <menu name>]
```
    
So each line is a path to a ROM with an optional name which will be used in the menu. Example:

```text
roms/Adventure Island (U) [!].nes | ADVENTURE ISLAND
roms/Adventure Island II (U) [!].nes | ADVENTURE ISLAND 2
roms/Adventure Island III (U) [!].nes | ADVENTURE ISLAND 3
```

Use a trailing "/" to add a whole directory:

```text
roms/
```

If the menu name is not specified, it will be based on the filename. The maximum length for a menu entry is 24 symbols.

You can use the "?" symbol as a game name to add hidden ROMs:

```text
spec/sram.nes | ? 
spec/controller.nes | ? 
```

* **First hidden ROM** will be started while holding **Up+A+B** at startup. 
* **Second hidden ROM** will be started while holding **Down+A+B** at startup (useful for adding hardware tests). 
* **Third hidden ROM** will be started using the **Konami Code** in the loader menu! 🕹️

### ℹ️ Important Information

* **Separators:** Unfortunately, in this project, you cannot use the "-" symbol to add separators between games, unlike in ClusterM's version.
* **Sorting Control:** You can disable sorting and enable a custom order using the `NOSORT=1` option when running Make. Alternatively, just add the `!NOSORT` line to a game list file.

💡 Check [configs/games.list](configs/games.list) for an example.

### ⚙️ How to Use Make

Just run the following command in your terminal:

```bash
make <targets> [options]
```

#### 🎯 Possible Targets
* **`menu`** — Build a menu file for **coolgirl-combiner** with "**combine**".
* **`nes20`** — Build a `.nes` file (NES 2.0).
* **`unif`** — Build a `.unf` file (UNIF).
* **`bin`** — Build a raw binary file, which can be used with a flash memory programmer.
* **`all`** — Build `.nes`, `.unf`, and `.bin` files at once.
* **`clean`** — Remove all temporary and output files.

#### 🔧 Possible Options
* **`MENU_SYMBOLS`** — Use as `MENU_SYMBOLS=menu_symbols.png` to specify an image for menu symbols (default is `menu_symbols.png`).
* **`LANGUAGE`** — Use as `LANGUAGE=eng` to specify loader messages language (`eng` or `rus`, default is `eng`).
* **`SIZE`** — Use as `SIZE=128` to set the maximum ROM size in megabytes (flash chip size). The builder will throw an error in case of ROM overflow (default is `128`).
* **`MAXCHRSIZE`** — Use as `MAXCHRSIZE=256` to set the maximum CHR size in kilobytes (CHR RAM chip size). The builder will throw an error if a game exceeds this size (default is `256`).
* **`OUTPUT_NES20`** — Use as `OUTPUT_NES20=output.nes` to set the output `.nes` file for the **nes20** target.
* **`OUTPUT_UNIF`** — Use as `OUTPUT_UNIF=output.unf` to set the output `.unf` file for the **unif** target.
* **`OUTPUT_BIN`** — Use as `OUTPUT_BIN=output.bin` to set the output `.bin` file for the **bin** target.
* **`CONFIGS_DIR`** — Use as `CONFIGS_DIR=configs` to set the directory with game list files (default is `configs`).
* **`ENABLE_LAST_GAME_SAVING`** — Use as `ENABLE_LAST_GAME_SAVING=1` to remember the last played game. Works only with `ENABLE_SAVES=1` and self-writable flash memory (default is `1`).
* **`NOSORT`** — Use as `NOSORT=1` to disable automatic alphabetical game sorting (default is `0`).
* **`BADSECTORS`** — Use as `BADSECTORS=0,5,10` to specify a list of bad sectors if you need to write to a cartridge with bad flash memory (default is none).
* **`REPORT`** — Use as `REPORT=report.txt` to specify a file for a human-readable build report (default is none).
* **`FADE_DELAY`** — Use as `FADE_DELAY=4` to set the dim speed (higher numbers mean slower fading, default is `DIM_IN_DELAY=4`).
* **`BUTTON_REPEAT_DELAY`** — Use as `BUTTON_REPEAT_DELAY=30` to set the number of frames before autorepeat starts (default is 30 frames, ~0.5 seconds at 60 FPS).
* **`BUTTON_REPEAT_RATE`** — Use as `BUTTON_REPEAT_RATE=15` to set the number of frames between repeated button presses when autorepeat is active (default is 15 frames, ~0.25 seconds at 60 FPS).

#### 💡 Examples

* **Change menu symbols:**
  ```bash
  make nes ENABLE_SAVES=1 MENU_SYMBOLS=menu_example.png
  ```
* **Save output ROM as a UNIF file:**
  ```bash
  make unif OUTPUT_UNIF=output.unf
  ```

## 🎮 Games Compatibility

Games compatibility depends heavily on the game's mapper. The supported mapper list is not constant and depends on the specific [cartridge firmware](https://github.com/ClusterM/coolgirl-famicom-multicart). There is a `coolgirl-mappers.json` file provided which contains the register values for all supported mappers.

## 🔍 In-Depth Info: How It Works

### 🔢 Method 1: Sequential Build
1. Run the command `make menu`. It will create a `.nes` file with the loader menu, convert menu symbol images to `menu_symbols.bin`, and copy it to the `src/bin` path. It automatically calculates the best way to fit game data into the target ROM and generates the default `games.inc` and offsets files.
   * `games.inc` contains game names and register values for the game loader menu. 
   * The offsets file contains info with addresses of data for every game in the final ROM (but does not contain the games data itself). You can fine-tune the loader menu using command-line options like dim speed, button repeat, etc.
2. Combine the loader menu and games into one file (`.nes`, `.unf`, or `.bin`) using **coolgirl-combiner** with the **"combine"** option and the offsets file generated in step 1.

### ⚡ Method 2: All-in-One Build (Easier & Faster)
1. Run the command `make nes`, `make unf`, or `make bin`. This option will automatically fit the games, compile assembly files using [ca65](https://cc65.github.io/doc/ca65.html), and combine everything into a single final file (`.nes`, `.unf`, or `.bin`) automatically.

## 📥 Download

You can always download the latest version from the [Releases]() section.