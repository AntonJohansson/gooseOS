pub fn outb(comptime port: u16, data: u8) void {
    asm volatile ("outb %[d], %[p]" :: [p] "i" (port), [d] "{rax}" (data));
}

pub fn inb(comptime port: u16) u8 {
    return asm volatile ("inb %[p], %[d]" : [d] "={rax}" (-> u8) : [p] "i" (port));
}
