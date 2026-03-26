// Programmable Interrupt Timer (PIT)
// model 8253,8254
//
// Chip with a stable clock that can interrupt the CPU at regular intervals.
// 3 channels exist: 
//
//   0: Clock tied to IRQ0;
//   1: System specific;
//   2: Speaker.
//
// we only care about channel 1 here.

const x86 = @import("x86.zig");

const frequency = 1193180;
const reg_data = 0x40; // Data register for channel 0
const reg_cmd  = 0x43; // Command register for channel 0,1,2

const Command = packed struct(u8) {
    // if unset, use 16-bit counters
    binary_coded_decimal: u1 = 0,
    mode: enum(u3) {
        terminal_count = 0, // Interrupt on terminal count
        one_shot       = 1, // Hardware retriggerable one-shot
        rate_generator = 2, // ?
        square_wave    = 3,
        strobe_sw      = 4,
        strobe_hw      = 5,
    },
    read_write: u2,
    counter: u2,
};

pub fn set_frequency(hz: u32) void {
    const divisor: u16 = @truncate(@divTrunc(frequency, hz));
    x86.outb(reg_cmd, @bitCast(Command {
        .mode = .square_wave,
        .read_write = 0b11,
        .counter = 0,
    }));
    x86.outb(reg_data, @truncate(divisor));
    x86.outb(reg_data, @truncate(divisor >> 8));
}
