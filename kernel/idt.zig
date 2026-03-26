// Interrupt Descriptor Table (IDT)

// Table 4-6. System-Segment Descriptor Types—Long Mode
// of the AMD64 Volume 2 System Programming Manual.
const Type = enum(u4) {
    ldt_64            = 0b0010,
    available_tss_64  = 0b1001,
    busy_tss_64       = 0b1011,
    call_gate_64      = 0b1100,
    interrupt_gate_64 = 0b1110,
    trap_gate_64      = 0b1111,
};

const Ring = u2;

// Figure 4-24: Interrupt-Gate and Trap-Gate Descriptors-Long Mode
// of the AMD64 Volume 2 System Programming Manual.
const Entry = packed struct(u128) {
    target_offset_0_15: u16 = 0,
    target_selector: u16 = 0,
    ist: u3 = 0,
    _0: u5 = 0, // reserved
    type: Type = .interrupt_gate_64,
    _1: u1 = 0, // always 0
    dpl: Ring = 0,
    present: u1 = 0, // p bit
    target_offset_16_31: u16 = 0,
    target_offset_32_63: u32 = 0,
    _2: u32 = 0, // reserved
};

const Register = packed struct {
    limit: u16,
    base: u64,
};

pub var table: [256]Entry align(16) = [_]Entry{.{}}**256;
pub var reg: Register align(16) = undefined;

pub const Isr = fn () callconv(.c) void;

pub fn set_entry(index: usize ,isr: *const Isr) void {
    const address: u64 = @intFromPtr(isr);
    table[index] = .{
        .target_offset_0_15  = @truncate(address),
        .target_offset_16_31 = @truncate(address >> 16),
        .target_offset_32_63 = @truncate(address >> 32),
        .target_selector = 0x8,
        .present = 1,
    };
}

pub fn load() void {
    // load IDT
    reg.limit = table.len*@sizeOf(Entry)-1;
    reg.base = @intFromPtr(&table[0]);
    asm volatile ("lidt %[ptr]" :: [ptr] "p" (&reg));
    asm volatile ("sti");
}

pub const Registers = packed struct {
    // General purpose registers
    rax: u64,
    rbx: u64,
    rcx: u64,
    rdx: u64,
    rsi: u64,
    rdi: u64,
    rsp: u64,
    rbp: u64,
    r8:  u64,
    r9:  u64,
    r10: u64,
    r11: u64,
    r12: u64,
    r13: u64,
    r14: u64,
    r15: u64,
    fs:  u64,
    gs:  u64,

    // Pushed by ISRs
    intvec: u64, 
    err:    u64,

    // Pushed by the processor
    rip:    u64,
    cs:     u64,
    rflags: u64,
    ss:     u64,
};
