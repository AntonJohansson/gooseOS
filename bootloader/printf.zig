const std  = @import("std");

// Scratch buffers for printf
var printf_buf: [256]u8 = undefined;
var printf_wbuf: [256]u16 = undefined;

// By Jarl Ostensen, converts 8 bit byte string to 16 bit.
fn toWide(dest: []u16, src: []const u8) void {
    for(src) |c, i| {
        dest[i] = @intCast(u16, c);
    }
    dest[src.len] = 0;
}

pub fn print(msg: []const u8) void {
    toWide(printf_wbuf[0..], msg);
    _ = std.os.uefi.system_table.con_out.?.outputString(@ptrCast([*:0] const u16, printf_wbuf[0..]));
}

pub fn printf(comptime format: []const u8, args: anytype) void {
    const fmt_buf: []u8 = std.fmt.bufPrint(printf_buf[0..], format, args) catch unreachable;
    print(fmt_buf);
}
