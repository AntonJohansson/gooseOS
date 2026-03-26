%define NEWL 0x0a,0x0d

; Function: print_char
;
; Prints a single character to the tty
;
; arguments:
;   al  character to print
print_char:
    push ax
    mov ah, 0x0e
    int 0x10
    pop ax
    ret

; Function: print_newl
;
; Prints a \r\n for a newline
print_newl:
    push ax
    mov al, 0x0a
    call print_char
    mov al, 0x0d
    call print_char
    pop ax
    ret

; Function: print_str
;
; Prints a null-terminated string to the tty
;
; arguments:
;   ds:si  null-terminated string to print
print_str:
    push ax
    push si

.loop:
    lodsb
    or al, al
    jz .done
    call print_char
    jmp .loop

.done:
    pop si
    pop ax
    ret

; Function: print_number
;
; Prints a number in any <= 16-bit base to the tty
;
; arguments:
;   ax  number to print
;   bl  base to print in
print_number:
    pusha
    mov bp, sp

    push ax

    ; push null terminator
    dec sp
    mov si, sp
    mov byte [si], 0

    mov cx, 16
    sub sp, cx
    mov di, sp
    mov al, ' '
    rep stosb

    mov ax, [bp-2]

.loop:
    div bl
    ; cl = *(str_nums + ah)
    movzx si, ah
    add si, str_nums
    mov cl, [si]
    ; *(--di) = cl
    sub di, 1
    mov byte [di], cl
    xor ah, ah
    cmp di, sp
    je .done
    or al, al
    jnz .loop

.done:
    cmp bl, 16
    jne .skip
    mov byte [di-1], 'x'
    mov byte [di-2], '0'
  .skip:

    mov si, sp
    call print_str

    mov sp, bp
    popa

    ret

; Function: print_hex
;
; Prints a hexadecimal number prefixed with `0x`
;
; arguments:
;   ax  number to print
print_hex:
    push bx
    mov bl, 16
    call print_number
    pop bx
    ret

; Print a message and then halt
;   si  message to print before halting
panic:
    mov di, si
    mov si, str_panic
    call print_str
    mov si, di
    call print_str
    cli
    hlt

;
; Data
;

str_panic            db "PANIC", NEWL, 0
str_nums             db "0123456789abcdef"
