// Programmable Interrupt Controllers (PICs or 8259s)
//
// Any IBM PC/AT compatible computer (286 and later) have two PICs
// daisy-chained, the masters (pic0) and slave (pic1) for a total of 15 IRQs.
// The output of pic1 is connected to IRQ2 of pic0, and the output of pic0 is
// connected directly to the CPU.  Whenever pic1 raises an IRQ, IRQ2 will fire
// as well.
//
// Normally IRQs [0,7] are mapped to [8,15] in the IDT, and IRQs [8,15] mapped
// to [0x70,0x78].  This is problematic since IDT entries [0,31] are reserved
// for exceptions and e.g. ISR 8 is a double fault.
//
// We need to remap the IRQs be reinitializing the PICs.

const x86 = @import("x86.zig");

// Data and command registers for both PICs.
const pic0_cmd  = 0x20;
const pic0_data = 0x21;
const pic1_cmd  = 0xa0;
const pic1_data = 0xa1;

// When initializing a PIC we supply 0x11 to the command word followed by
// 4 data words.  0x11 corresponds to "init" + "there is a fourth data word".
//
//   1. Command;
//   2. Vector offset to add to IRQs;
//   3. Cascaded wiring
//   4. Environment

const icw1_icw4      = 0x01; // Indicates that icw4 is present
const icw1_single    = 0x02; // Single mode, cascaded otherwise
const icw1_interval4 = 0x04; // Call address interval 4, 8 otherwise
const icw1_level     = 0x08; // Level triggered if set, edge triggered otherwise
const icw1_init      = 0x10; // Initialization required
const icw1_eoi       = 0x20; // Signal CPU is done processing interrupt
const icw1_read_irr  = 0x0a; // Read the Interrupt Request Reqister (IRR)
const icw1_read_isr  = 0x0b; // Read the Interrupt Request Reqister (ISR)

const icw4_8086       = 0x01; // 8086/88 mode
const icw4_auto       = 0x02; // Auto end-of-interrupt, normal otherwise
const icw4_buf_slave  = 0x08; // buffered mode, slave
const icw4_buf_master = 0x0c; // buffered_mode, master
const icw4_sfnm       = 0x10; // special fully nested (?), not otherwise

// pic1 -> pic0 IRQ wiring
const cascade_irq = 2;

pub fn irq_remap() void {
    // init + icw4 present
    x86.outb(pic0_cmd, icw1_init | icw1_icw4);
    x86.outb(pic1_cmd, icw1_init | icw1_icw4);
    // vector base
    x86.outb(pic0_data, 0x20);
    x86.outb(pic1_data, 0x28);
    // cascading
    x86.outb(pic0_data, 1 << cascade_irq);
    x86.outb(pic1_data, cascade_irq);
    // environment
    x86.outb(pic0_data, icw4_8086);
    x86.outb(pic1_data, icw4_8086);
    // At this point initialization is done, unmask both PICs
    enable();
}

pub fn end_of_interrupt(irq: u8) void {
    // If pic1 triggered the IRQ, notify both, else notify
    // only pic0.
    if (irq >= 8) {
        x86.outb(pic1_cmd, icw1_eoi);
    }
    x86.outb(pic0_cmd, icw1_eoi);
}

// The PICs each contain an 8-bit Interrupt Mask Register (IMR) with the n:th
// if IRQn is to be masked (ignored).  The IMR can be set via the data register after initialization.

pub fn enable() void {
    // unmask all interrupts on both PICs.
    x86.outb(pic0_data, 0x00);
    x86.outb(pic1_data, 0x00);
}

pub fn disable() void {
    // mask all interrupts on both PICs.
    x86.outb(pic0_data, 0xff);
    x86.outb(pic1_data, 0xff);
}

pub fn mask(irq: u8) void {
    const pic_port = if (irq < 8) pic0_data else pic1_data;
    const pic_irq = if (irq < 8) irq else irq - 8;
    const value = x86.inb(pic_port) | (1 << pic_irq);
    x86.outb(pic_port, value);
}

pub fn unmask(irq: u8) void {
    const pic_port = if (irq < 8) pic0_data else pic1_data;
    const pic_irq = if (irq < 8) irq else irq - 8;
    const value = x86.inb(pic_port) & ~(1 << pic_irq);
    x86.outb(pic_port, value);
}

// For bookkeeping the PICs use two other 8-bit reqisters the:
//
//   In-Service Register (ISR), and;
//   Interrupt Request Register (IRR).
//
// The n:th bit in the IRR is set whenever IRQn is raised in the PIC, and the
// n:th bit of the ISR is set to ~IMR & IRR, whenever the PIC raised the CPU
// interrupt line, marking the unmaskhed interrupts in the IRR as being
// "serviced" by the CPU.
//
// These reqisters can be read by first writing and then reading from the
// command port.

fn read_irr() u16 {
    x86.outb(pic0_cmd, icw1_read_irr);
    x86.outb(pic1_cmd, icw1_read_irr);
    const pic0_irr: u16 = x86.inb(pic0_cmd);
    const pic1_irr: u16 = x86.inb(pic1_cmd);
    return (pic1_irr << 8) | pic0_irr;
}

fn read_isr() u16 {
    x86.outb(pic0_cmd, icw1_read_isr);
    x86.outb(pic1_cmd, icw1_read_isr);
    const pic0_isr: u16 = x86.inb(pic0_cmd);
    const pic1_isr: u16 = x86.inb(pic1_cmd);
    return (pic1_isr << 8) | pic0_isr;
}

// PICs signal to the CPU that an IRQ has occured before they send the
// interrupt vector, therefore a race condition can occur if
//
// CPU                     PIC                      DEVICE
//  |                       | <-[raises IRQ0 in IRR]- |
//  |                       |
//  |                 [Updates ISR]
//  |                       |
//  | <---[IRQ ready]------ |
//  |                       |
//  | -[end-of-interrupt]-> |                      
//  |                       |
//  |                  [Clears ISR]
//  |                       |
//  | <---[Sends IRQ7]----- |
//
// as ISR is cleared before the PIC has sent out the IRQ vector, it sends
// the lowest priority IRQ7 (15 if pic1).  This is a "spurious" IRQ that
// should be ignored, as an interrupt was raised but the PIC doesn't know
// which.

pub fn handle_spurious(irq: u8) bool {
    // Spurious IRQs are sent on the lowest priority lines
    // for each PIC (7 and 15).
    if (irq != 7 and irq != 15) {
        @branchHint(.likely);
        return false;
    }

    // If we get an IRQ on 7 or 15, verify with the ISR that
    // the IRQ is real.
    const isr = read_isr();
    if (isr & ((1 << 7) | (1 << 15)) != 0) {
        @branchHint(.likely);
        // If the ISR field is set, then the IRQ is real.
        return false;
    }

    // If IRQ15 is spurious we need to notify pic0 to clear ISR15.
    if (irq == 15) {
        x86.outb(pic0_cmd, icw1_eoi);
    }

    return true;
}
