; --- GAME CONSTANTS CONFIGURATION ---
MAPPER      = 2     ; Mapper number (e.g., 4 = MMC3)
SUBMAPPER   = 0     ; Submapper number (0 = none)
MIRRORING   = 1     ; 0 = Horizontal, 1 = Vertical
BATTERY     = 0     ; 1 = Battery-backed RAM present, 0 = None
REGION      = 0     ; 0 = NTSC, 1 = PAL, 3 = Dendy

PRG_BANKS   = 8     ; Number of 16 KB PRG ROM banks (8 * 16 = 128 KB)
CHR_BANKS   = 0     ; Number of 8 KB CHR ROM banks (0 if using CHR RAM)

; RAM sizes (defined as shift counts / exponents: 0=none, 5=2KB, 6=4KB, 7=8KB, 8=16KB, 9=32KB, etc.)
PRG_RAM_SIZE  = 0   ; Work RAM size (0 = none)
PRG_NVRAM_SIZE= 0   ; Non-volatile / Battery-backed PRG RAM size (0 = none)
CHR_RAM_SIZE  = 7   ; CHR RAM size for graphics (8 = 16 KB)
CHR_NVRAM_SIZE= 0   ; Non-volatile / Battery-backed CHR RAM size (0 = none)

.segment "INESHDR"
    .byte $4E, $45, $53, $1A        ; Byte 0-3: Magic string "NES" + EOF
    .byte (PRG_BANKS & $FF)         ; Byte 4: Lower 8 bits of PRG ROM size
    .byte (CHR_BANKS & $FF)         ; Byte 5: Lower 8 bits of CHR ROM size
    
    ; Byte 6: Mirroring, battery, trainer, and lower nibble of mapper number
    .byte (MIRRORING & 1) | ((BATTERY & 1) << 1) | ((MAPPER & $0F) << 4)
    
    ; Byte 7: Upper nibble of mapper number + NES 2.0 identifier (%10 in bits 2-3)
    .byte (MAPPER & $F0) | %00001000
    
    ; Byte 8: Mapper highest bits and submapper number
    .byte ((MAPPER >> 8) & $0F) | ((SUBMAPPER & $0F) << 4)
    
    ; Byte 9: Upper bits of PRG and CHR ROM sizes
    .byte ((PRG_BANKS >> 8) & $0F) | (((CHR_BANKS >> 8) & $0F) << 4)
    
    ; Byte 10: PRG RAM and PRG NVRAM sizes
    .byte (PRG_RAM_SIZE & $0F) | ((PRG_NVRAM_SIZE & $0F) << 4)
    
    ; Byte 11: CHR RAM and CHR NVRAM sizes
    .byte (CHR_RAM_SIZE & $0F) | ((CHR_NVRAM_SIZE & $0F) << 4)
    
    ; Byte 12: CPU timing / Region identification
    .byte (REGION & $03)
    
    ; Byte 13: System type (0 = Standard NES/Famicom)
    .byte 0
    
    ; Byte 14-15: Reserved bytes for future extension
    .byte 0, 0