const BootloaderApi = @import("bootloader_api").BootloaderApi;
const idt = @import("idt.zig");
const pic = @import("pic.zig");
const pit = @import("pit.zig");
const ps2 = @import("ps2.zig");
const console = @import("console.zig");

// RGBA8
//const Framebuffer = extern struct {
//    base: [*]align(4) u8,
//    size: u32,
//    width: u32,
//    height: u32,
//    pps: u32,
//};

const IrqHandler = fn (registers: *idt.Registers) void;

var handlers = [_]?*const IrqHandler{null}**16;

export fn irq_handler(registers: *idt.Registers) void {
    const irq: u8 = @truncate(registers.intvec - 32);
    if (pic.handle_spurious(irq)) {
        return;
    }
    if (handlers[irq]) |f| {
        f(registers);
    }
    pic.end_of_interrupt(irq);
}

export fn isr_handler(registers: *idt.Registers) void {
    const isr: u8 = @truncate(registers.intvec);
    console.log_fmt("ISR: {}", .{isr});
    asm volatile ("hlt");
}

extern const isr_stub_table: u64;
extern const irq_stub_table: u64;

export fn _start(api: *BootloaderApi) noreturn {
    // pass along framebuffer info
    console.framebuffer = api.fb_base;
    console.width = api.fb_width;
    console.height = api.fb_height;

    // IRQs
    pic.irq_remap();
    handlers[1] = ps2.handler;
    ps2.init();
    for (0..16) |i| {
        const arr: [*]const u64 = @ptrCast(&irq_stub_table);
        const ptr: *idt.Isr = @ptrFromInt(arr[i]);
        idt.set_entry(32 + i, ptr);
    }

    // ISRs
    for (0..32) |i| {
        const arr: [*]const u64 = @ptrCast(&isr_stub_table);
        const ptr: *idt.Isr = @ptrFromInt(arr[i]);
        idt.set_entry(i, ptr);
    }

    idt.load();

    pit.set_frequency(2);

    while (true) {
        asm volatile ("nop");
    }

    //const a = 1;
    //const b = 0;
    //asm volatile(
    //\\ div %[num1]
    //:: [num0] "{rax}" (a),
    //  [num1] "{rbx}" (b)
    //);

    //while (true) {
    //    asm volatile ("hlt");
    //}
}
