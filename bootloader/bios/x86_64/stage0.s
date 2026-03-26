%include "./zig-out/bin/generated-stage-0.s"

org stage0_base
bits 16

; https://wiki.osdev.org/FAT
; BIOS Parameter Block (BPB)
jmp short 0x3c
nop
bpb_oem                     db "MSWIN4.1"
bpb_bytes_per_sector        dw sector_size
bpb_sectors_per_cluster     db 1
bpb_reserved_sectors        dw reserved_sectors
bpb_num_fats                db 2
bpb_num_root_dir_entries    dw 224
bpb_num_sectors             dw 2880
bpb_media_type              db 0xf0 ; 0xf8 hard disk, 0xf0 floppy
bpb_sectors_per_fat         dw 9
bpb_sectors_per_track       dw 18
bpb_heads                   dw 2
bpb_hidden_sectors          dd 0
bpb_large_sector_count      dd 0

; Extended Boot Record (EBR)
erb_drive_number            db 0 ; 0x80 hard disk, 0x00 for floppy
                            db 0 ; reserved
erb_signature               db 0x28
erb_volume_id               dd 0
erb_volume_label            db "gooseloader" ; 11 bytes
erb_system_id               db "FAT12   "    ;  8 bytes

;
; Stage 0 bootloader code
;

; Jump to main routine, also clear out cs with a jump, some BIOS
; loads the boot sector at 0000:7c00, others at 7c00:0000 or some
; other unholy variation.
jmp 0:stage0

; includes
%include "bootloader/bios/x86_64/print.s"

stage0:
    ; Zero out all segment registers
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax

    ; Setup stack
    mov bp, stage0_base
    mov sp, bp

    ; BIOS passes boot drive as dl, save it for later use
    mov [boot_drive], dl

    mov ah, 0x2 ; read sectors
    mov al, stage1_sectors ; number of sectors to read
    mov ch, 0 ; cylinder
    mov cl, 1 + stage0_sectors ; sector number (starts at 1)
    mov dh, 0 ; head number
    mov dl, [boot_drive] ; drive number
    mov bx, stage1_base
    int 0x13

    jnc .valid
    mov si, str_stage1_load_fail
    jmp panic
.valid:

    mov si, str_stage0_finished
    call print_str

    mov ax, [boot_drive]
    mov bx, kernel_base_sector
    jmp stage1_base

;
; Stage 0 data
;
boot_drive dw 0
; strings
str_stage1_load_fail db "stage0: Not able to load stage1!", NEWL, 0
str_stage0_finished  db "stage0: Finished, jumping to stage1", NEWL, 0

; Fill remaining bytes of bootsector with 0s until we get to 510 bytes in size,
; then append the 0xAA55 signature so POST knows we're bootable,
;   $       current offset in memory of current line code
;   $$      offset in memory of current segment
;   $-$$    current offset in binary
times sector_size - 2 - ($-$$) db 0
dw 0xAA55
