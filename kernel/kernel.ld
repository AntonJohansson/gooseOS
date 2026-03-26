OUTPUT_FORMAT(elf64-x86-64)
ENTRY(_start)

SECTIONS
{
    . = 0x100000;
    . = ALIGN(0x1000);

    .text : {
        *(.text)
    }
    .data : {
        *(.data)
    }
    .rodata : {
        *(.rodata)
    }
    .bss : {
        *(COMMON)
        *(.bss)
    }

    . = ALIGN(0x1000);
}
