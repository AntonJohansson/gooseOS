section .text
bits 64

%macro isr_stub_n_err 1
global _isr%+%1
_isr%+%1:
    cli
    push qword 0
    push qword %1
    jmp isr_common_stub
%endmacro

%macro isr_stub_y_err 1
global _isr%+%1
_isr%+%1:
    cli
    push qword %1
    jmp isr_common_stub
%endmacro

%macro irq_stub_n_err 1
global _irq%+%1
_irq%+%1:
    cli
    push qword 0
    push qword %1
    jmp irq_common_stub
%endmacro

isr_stub_n_err 0 ; 	n Division By Zero Exception
isr_stub_n_err 1 ; 	n Debug Exception
isr_stub_n_err 2 ; 	n Non Maskable Interrupt Exception
isr_stub_n_err 3 ; 	n Breakpoint Exception
isr_stub_n_err 4 ; 	n Into Detected Overflow Exception
isr_stub_n_err 5 ; 	n Out of Bounds Exception
isr_stub_n_err 6 ; 	n Invalid Opcode Exception
isr_stub_n_err 7 ; 	n No Coprocessor Exception
isr_stub_y_err 8 ; 	y Double Fault Exception
isr_stub_n_err 9 ; 	n Coprocessor Segment Overrun Exception
isr_stub_y_err 10 ; 	y Bad TSS Exception
isr_stub_y_err 11 ; 	y Segment Not Present Exception
isr_stub_y_err 12 ; 	y Stack Fault Exception
isr_stub_y_err 13 ; 	y General Protection Fault Exception
isr_stub_y_err 14 ; 	y Page Fault Exception
isr_stub_n_err 15 ; 	n Unknown Interrupt Exception
isr_stub_n_err 16 ; 	n Coprocessor Fault Exception
isr_stub_n_err 17 ; 	n Alignment Check Exception (486+)
isr_stub_n_err 18 ; 	n Machine Check Exception (Pentium/586+)
isr_stub_n_err 19 ; 	reserved
isr_stub_n_err 20 ; 	reserved
isr_stub_n_err 21 ; 	reserved
isr_stub_n_err 22 ; 	reserved
isr_stub_n_err 23 ; 	reserved
isr_stub_n_err 24 ; 	reserved
isr_stub_n_err 25 ; 	reserved
isr_stub_n_err 26 ; 	reserved
isr_stub_n_err 27 ; 	reserved
isr_stub_n_err 28 ; 	reserved
isr_stub_n_err 29 ; 	reserved
isr_stub_n_err 30 ; 	reserved
isr_stub_n_err 31 ; 	reserved

irq_stub_n_err 32
irq_stub_n_err 33
irq_stub_n_err 34
irq_stub_n_err 35
irq_stub_n_err 36
irq_stub_n_err 37
irq_stub_n_err 38
irq_stub_n_err 39
irq_stub_n_err 40
irq_stub_n_err 41
irq_stub_n_err 42
irq_stub_n_err 43
irq_stub_n_err 44
irq_stub_n_err 45
irq_stub_n_err 46
irq_stub_n_err 47

global isr_stub_table
isr_stub_table:
%assign i 0
%rep 32
    dq _isr%+i
%assign i i+1
%endrep

global irq_stub_table
irq_stub_table:
%assign i 32
%rep 16
    dq _irq%+i
%assign i i+1
%endrep

extern isr_handler
extern irq_handler

; This is our common ISR stub. It saves the processor state, sets
; up for kernel mode segments, calls the C-level fault handler,
; and finally restores the stack frame.
isr_common_stub:
    push fs 
    push gs 
    push r15
    push r14
    push r13
    push r12
    push r11
    push r10
    push r9
    push r8
    push rbp
    push rsp
    push rdi
    push rsi
    push rdx
    push rcx
    push rbx
    push rax

    ; reserved for use as base of thread local storage
    ; other segment registers hold no value in 64 bit mode
    ; processor local storage

    mov rdi, rsp
    call isr_handler

    pop rax
    pop rbx
    pop rcx
    pop rdx
    pop rsi
    pop rdi
    pop rsp
    pop rbp
    pop r8
    pop r9
    pop r10
    pop r11
    pop r12
    pop r13
    pop r14
    pop r15
    pop fs 
    pop gs 

    add rsp, 16    ; Cleans up the pushed error code and pushed ISR number
    iretq           ; pops 5 things at once: CS, EIP, EFLAGS, SS, and ESP!

; This is our common ISR stub. It saves the processor state, sets
; up for kernel mode segments, calls the C-level fault handler,
; and finally restores the stack frame.
irq_common_stub:
    push fs 
    push gs 
    push r15
    push r14
    push r13
    push r12
    push r11
    push r10
    push r9
    push r8
    push rbp
    push rsp
    push rdi
    push rsi
    push rdx
    push rcx
    push rbx
    push rax

    ; reserved for use as base of thread local storage
    ; other segment registers hold no value in 64 bit mode
    ; processor local storage

    mov rdi, rsp
    call irq_handler

    pop rax
    pop rbx
    pop rcx
    pop rdx
    pop rsi
    pop rdi
    pop rsp
    pop rbp
    pop r8
    pop r9
    pop r10
    pop r11
    pop r12
    pop r13
    pop r14
    pop r15
    pop fs 
    pop gs 

    add rsp, 16    ; Cleans up the pushed error code and pushed ISR number
    iretq           ; pops 5 things at once: CS, EIP, EFLAGS, SS, and ESP!
