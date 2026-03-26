%include "./zig-out/bin/generated-stage-1.s"

org stage1_base
bits 16

;
; Stage 1 bootloader code
;

jmp 0:stage1

; includes
%include "bootloader/bios/x86_64/print.s"
%include "bootloader/bios/x86_64/a20.s"
%include "bootloader/bios/x86_64/long.s"
%include "bootloader/bios/x86_64/vesa.s"

align(8)
api: istruc BootloaderApi
    times BootloaderApi_Size db 0
iend

; Needs to be the first thing in stage1, label is used as address to load
; stage 1 from stage 0
stage1:
    mov [boot_drive], ax
    mov [kernel_base_sector], bx

    call try_enable_a20

    mov ax, 640
    mov bx, 480
    mov cl, 32
    call vbe_set_mode

    mov ah, 0x2 ; read sectors
    mov al, kernel_sectors ; number of sectors to read
    mov ch, 0 ; cylinder
    mov cl, 1
    add cl, [kernel_base_sector] ; sector number (starts at 1)
    mov dh, 0 ; head number
    mov dl, [boot_drive] ; drive number
    mov bx, kernel_segment
    mov es, bx
    mov bx, kernel_offset
    int 0x13

    ;mov cx, 0x2000
    ;mov bx, 0x6900
    ;mov es, bx
    ;mov di, 0
    ;mov bx, 0xffff
    ;mov ds, bx
    ;mov si, 16
    ;rep movsd

    jnc .valid
    mov si, str_kernel_load_fail
    jmp panic
.valid:


;    jnc .noerr
;    mov ax, 123
;    mov bl, 10
;    call print_number
;    cli
;    hlt
;  .noerr:

    jmp enter_protected_mode

;    mov bx, page_segment
;    mov es, bx
;    mov edi, page_offset
;    mov ss, bx
;    mov esp, page_offset
; jmp SwitchToLongMode

bits 32
protected_mode:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    jmp enter_long_mode

bits 64
long_mode:
    cli
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    xor rax, rax
    mov eax, dword [abs vbe_screen.physical_buffer]
    mov [abs api+BootloaderApi.fb_base], rax
    mov ax, [abs vbe_screen.width]
    mov [abs api+BootloaderApi.fb_width], ax
    mov ax, [abs vbe_screen.height]
    mov [abs api+BootloaderApi.fb_height], ax
    mov ax, [abs vbe_screen.bytes_per_line]
    mov [abs api+BootloaderApi.fb_bytes_per_line], ax
    mov eax, [abs vbe_screen.bytes_per_pixel]
    mov [abs api+BootloaderApi.fb_bytes_per_pixel], eax

    mov rbp, 0x10ffff
    mov rsp, rbp

    mov rdi, api
    call kernel_entry
;
; Stage 1 data
;

boot_drive: dw 0
kernel_base_sector: dw 0
str_kernel_load_fail db "failed to load kernel :c", NEWL, 0
