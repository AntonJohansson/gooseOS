  struc VesaInfoBlock                ;    VesaInfoBlock_size = 512 bytes
    .Signature        resb 4        ;    must be 'VESA'
    .Version        resw 1
    .OEMNamePtr        resd 1
    .Capabilities        resd 1
 
    .VideoModesOffset    resw 1
    .VideoModesSegment    resw 1
 
    .CountOf64KBlocks    resw 1
    .OEMSoftwareRevision    resw 1
    .OEMVendorNamePtr    resd 1
    .OEMProductNamePtr    resd 1
    .OEMProductRevisionPtr    resd 1
    .Reserved        resb 222
    .OEMData        resb 256
endstruc

struc VesaModeInfoBlock                ;    VesaModeInfoBlock_size = 256 bytes
    .ModeAttributes        resw 1
    .FirstWindowAttributes    resb 1
    .SecondWindowAttributes    resb 1
    .WindowGranularity    resw 1        ;    in KB
    .WindowSize        resw 1        ;    in KB
    .FirstWindowSegment    resw 1        ;    0 if not supported
    .SecondWindowSegment    resw 1        ;    0 if not supported
    .WindowFunctionPtr    resd 1
    .BytesPerScanLine    resw 1
 
    ;    Added in Revision 1.2
    .Width            resw 1        ;    in pixels(graphics)/columns(text)
    .Height            resw 1        ;    in pixels(graphics)/columns(text)
    .CharWidth        resb 1        ;    in pixels
    .CharHeight        resb 1        ;    in pixels
    .PlanesCount        resb 1
    .BitsPerPixel        resb 1
    .BanksCount        resb 1
    .MemoryModel        resb 1        ;    http://www.ctyme.com/intr/rb-0274.htm#Table82
    .BankSize        resb 1        ;    in KB
    .ImagePagesCount    resb 1        ;    count - 1
    .Reserved1        resb 1        ;    equals 0 in Revision 1.0-2.0, 1 in 3.0
 
    .RedMaskSize        resb 1
    .RedFieldPosition    resb 1
    .GreenMaskSize        resb 1
    .GreenFieldPosition    resb 1
    .BlueMaskSize        resb 1
    .BlueFieldPosition    resb 1
    .ReservedMaskSize    resb 1
    .ReservedMaskPosition    resb 1
    .DirectColorModeInfo    resb 1
 
    ;    Added in Revision 2.0
    .LFBAddress        resd 1
    .OffscreenMemoryOffset    resd 1
    .OffscreenMemorySize    resw 1        ;    in KB
    .Reserved2        resb 206    ;    available in Revision 3.0, but useless for now
endstruc

ALIGN(8)
 
	VesaInfoBlockBuffer: istruc VesaInfoBlock
		at VesaInfoBlock.Signature,				db "VESA"
		times 508 db 0
	iend


ALIGN(8)
 
	VesaModeInfoBlockBuffer: istruc VesaModeInfoBlock
		times 256 db 0
	iend

ALIGN(8)
vbe_screen:
    .width dw 0
    .height dw 0
    .physical_buffer dd 0
    .bytes_per_line dw 0
    .bpp dw 0
    .bytes_per_pixel dd 0
    .x_cur_max dw 0
    .y_cur_max dw 0

; vbe_set_mode:
; Sets a VESA mode
; In\    AX = Width
; In\    BX = Height
; In\    CL = Bits per pixel
; Out\    FLAGS = Carry clear on success
; Out\    Width, height, bpp, physical buffer, all set in vbe_screen structure
 
vbe_set_mode:
    mov [.width], ax
    mov [.height], bx
    mov [.bpp], cl
 
    sti
 
    push es                    ; some VESA BIOSes destroy ES, or so I read
    mov ax, 0x4F00                ; get VBE BIOS info
    mov di, VesaInfoBlockBuffer
    int 0x10
    pop es
 
    cmp ax, 0x4F                ; BIOS doesn't support VBE?
    jne .error
 
    mov ax, word[VesaInfoBlockBuffer+VesaInfoBlock.VideoModesOffset]
    mov [.offset], ax
    mov ax, word[VesaInfoBlockBuffer+VesaInfoBlock.VideoModesOffset+2]
    mov [.segment], ax
 
    mov ax, [.segment]
    mov fs, ax
    mov si, [.offset]
 
.find_mode:
    mov dx, [fs:si]
    add si, 2
    mov [.offset], si
    mov [.mode], dx
    mov ax, 0
    mov fs, ax
 
    cmp word [.mode], 0xFFFF            ; end of list?
    je .error
 
    push es
    mov ax, 0x4F01                ; get VBE mode info
    mov cx, [.mode]
    mov di, VesaModeInfoBlockBuffer
    int 0x10
    pop es
 
    cmp ax, 0x4F
    jne .error
 
    mov ax, [.width]
    cmp ax, [VesaModeInfoBlockBuffer+VesaModeInfoBlock.Width]
    jne .next_mode
 
    mov ax, [.height]
    cmp ax, [VesaModeInfoBlockBuffer+VesaModeInfoBlock.Height]
    jne .next_mode
 
    mov al, [.bpp]
    cmp al, [VesaModeInfoBlockBuffer+VesaModeInfoBlock.BitsPerPixel]
    jne .next_mode
 
    ; If we make it here, we've found the correct mode!
    mov ax, [.width]
    mov word[vbe_screen.width], ax
    mov ax, [.height]
    mov word[vbe_screen.height], ax
    mov eax, [VesaModeInfoBlockBuffer+VesaModeInfoBlock.LFBAddress]
    mov dword[vbe_screen.physical_buffer], eax
    mov ax, [VesaModeInfoBlockBuffer+VesaModeInfoBlock.BytesPerScanLine]
    mov word[vbe_screen.bytes_per_line], ax
    mov eax, 0
    mov al, [.bpp]
    mov byte[vbe_screen.bpp], al
    shr eax, 3
    mov dword[vbe_screen.bytes_per_pixel], eax
 
    mov ax, [.width]
    shr ax, 3
    dec ax
    mov word[vbe_screen.x_cur_max], ax
 
    mov ax, [.height]
    shr ax, 4
    dec ax
    mov word[vbe_screen.y_cur_max], ax
 
    ; Set the mode
    push es
    mov ax, 0x4F02
    mov bx, [.mode]
    or bx, 0x4000            ; enable LFB
    mov di, 0            ; not sure if some BIOSes need this... anyway it doesn't hurt
    int 0x10
    pop es
 
    cmp ax, 0x4F
    jne .error
 
    clc
    ret
 
.next_mode:
    mov ax, [.segment]
    mov fs, ax
    mov si, [.offset]
    jmp .find_mode
 
.error:
    stc
    ret
 
.width                dw 0
.height                dw 0
.bpp                db 0
.segment            dw 0
.offset                dw 0
.mode                dw 0
