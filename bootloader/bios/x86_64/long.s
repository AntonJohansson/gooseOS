%define PAGE_PRESENT    (1 << 0)
%define PAGE_WRITE      (1 << 1)

%define CODE_SEG     0x0008
%define DATA_SEG     0x0010

enter_protected_mode:
    xor ax, ax
    mov ds, ax
    cli ; disable interrupts
    lgdt [gdt32_desc]
    mov eax, cr0
    or al, 1
    mov cr0, eax
    jmp 0x0008:protected_mode

align 4
IDT:
    .Length       dw 0
    .Base         dd 0

bits 32
enter_long_mode:
    ; Zero out bytes for page tables
    ;  edi start address1
    ;  eax value to fill with
    ;  ecx number of dw to fill
    mov edi, 0x1000
    mov cr3, edi
    xor eax, eax
    mov ecx, 2*6*512
    rep stosd
    mov edi, cr3

    mov eax, dword [vbe_screen.physical_buffer]
    shr eax, 12
    shr eax, 9
    mov ebx, eax
    and ebx, 0b111111111
    shl ebx, 3
    shr eax, 9
    mov ecx, eax
    and ecx, 0b111111111
    shl ecx, 3

    ; 0x1000 L4
    ; 0x2000 L3
    ; 0x3000 L2
    ; 0x4000 L1
    ; 0x5000 L2.1
    ; 0x6000 L1.1
    ; L4[0] -> L3
    mov edi, 0x1000
    mov dword [edi], 0x2003
    ; L3[0] -> L2
    mov edi, 0x2000
    mov dword [edi], 0x3003
    ; L3[3] -> L2.1
    lea edi, [0x2000 + ecx]
    mov dword [edi], 0x5003
    ; L2[0] -> L1
    mov edi, 0x3000
    mov dword [edi], 0x4003
    ; L2.1[256] -> L1.1
    lea edi, [0x5000 + ebx]
    mov dword [edi], 0x6003

    mov edi, 0x4000
    mov ebx, 0x3
    mov ecx, 512
  .set:
    mov dword [edi], ebx
    add ebx, 0x1000
    add edi, 8
    loop .set

    mov edi, 0x6000
    mov ebx, dword [vbe_screen.physical_buffer]
    add ebx, 0x3
    mov ecx, 512
  .set2:
    mov dword [edi], ebx
    add ebx, 0x1000
    add edi, 8
    loop .set2

    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax

    ; enter compatability mode
    mov ecx, 0xc0000080
    rdmsr
    or eax, 1 << 8 ; LM bit
    wrmsr
    mov eax, cr0
    or eax, 1 << 31 ; PG bit
    mov cr0, eax
    lgdt [gdt64_desc]

    jmp 0x0008:long_mode

bits 16

; Global Descriptor Table
align(4)
gdt32:
.null:
    dq 0x0000000000000000             ; Null Descriptor - should be present.
.code:
    ;                              0x15151  unscaled size of seg.
    ;                           0xbcbcbcbc  base address of seg.
    ;         ┌─┬──┬─┐                   A  accessed, set by cpu when used
    ;         │F│PL│S│                 │ R  (S=1,T=1) 0 - exec, 1 - exec/read
    ;         │ ┌────┘                 │    (S=1,T=0) 0 - read, 1 - write/read
    ; ┌─┬─┬─┬─┤ ├─┬─┬─┬─┐         bits │ C  conforming, enb. low -> high PL jmp
    ; │G│Z│-│?│ │T│C│R│A│              │ T  (S=1) seg. is 0 - data, 1 - code
    ; └───┐ ┌─┤ │ ┌─────┘              │ S  0 - LDT,TSS,GATE; 1 - code,data
    ;  ╒══╡ ╞═╡ │ ╞══════╤════╕        │PL  priv. level  0 highest -- 3 lowest
    ;  │bc│ │1│ │ │bcbcbc│5151│   hex  │ F  seg. loaded in memory?
    ;  ╞══╪═╪═╪═╪═╪══════╪════╡        │ ?  ignored by cpu
    ;  │  │ │┌┘ │ │      │    │        │ -  reserved by intel, must be 0
    ;  └─┐└┐││┌─┘ │  ┌───┘    │        │ Z  0 - 16-bit, 1 - 32-bit
    ;    │ ││││┌──┘  │   ┌────┘        │ G  scale seg. size by 4KiB?
    dq 0x00cf9a000000ffff
.data:
    dq 0x00cf92000000ffff
gdt32_end:
gdt32_desc:
    dw gdt32_end - gdt32 - 1
    dd gdt32

align(8)
gdt64:
.null:
    dq 0x0000000000000000             ; Null Descriptor - should be present.
.code:
    ;                              0x15151  unscaled size of seg.
    ;                           0xbcbcbcbc  base address of seg.
    ;         ┌─┬──┬─┐                   A  accessed, set by cpu when used
    ;         │F│PL│S│                 │ R  (S=1,T=1) 0 - exec, 1 - exec/read
    ;         │ ┌────┘                 │    (S=1,T=0) 0 - read, 1 - write/read
    ; ┌─┬─┬─┬─┤ ├─┬─┬─┬─┐         bits │ C  conforming, enb. low -> high PL jmp
    ; │G│Z│L│?│ │T│C│R│A│              │ T  (S=1) seg. is 0 - data, 1 - code
    ; └───┐ ┌─┤ │ ┌─────┘              │ S  0 - LDT,TSS,GATE; 1 - code,data
    ;  ╒══╡ ╞═╡ │ ╞══════╤════╕        │PL  priv. level  0 highest -- 3 lowest
    ;  │bc│ │1│ │ │bcbcbc│5151│   hex  │ F  seg. loaded in memory?
    ;  ╞══╪═╪═╪═╪═╪══════╪════╡        │ ?  ignored by cpu
    ;  │  │ │┌┘ │ │      │    │        │ L  long mode
    ;  └─┐└┐││┌─┘ │  ┌───┘    │        │ Z  0 - 32-bit, 1 - 64-bit
    ;    │ ││││┌──┘  │   ┌────┘        │ G  scale seg. size by 4KiB?
    dq 0x00af9a000000ffff
.data:
    dq 0x00af92000000ffff
gdt64_end:
gdt64_desc:
    dw gdt64_end - gdt64 - 1
    dq gdt64
