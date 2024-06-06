const std = @import("std");
const uefi = std.os.uefi;

// colors
const black        = uefi.protocol.SimpleTextOutput.black;
const blue         = uefi.protocol.SimpleTextOutput.blue;
const green        = uefi.protocol.SimpleTextOutput.green;
const cyan         = uefi.protocol.SimpleTextOutput.cyan;
const red          = uefi.protocol.SimpleTextOutput.red;
const magenta      = uefi.protocol.SimpleTextOutput.magenta;
const brown        = uefi.protocol.SimpleTextOutput.brown;
const lightgray    = uefi.protocol.SimpleTextOutput.lightgray;
const bright       = uefi.protocol.SimpleTextOutput.bright;
const darkgray     = uefi.protocol.SimpleTextOutput.darkgray;
const lightblue    = uefi.protocol.SimpleTextOutput.lightblue;
const lightgreen   = uefi.protocol.SimpleTextOutput.lightgreen;
const lightcyan    = uefi.protocol.SimpleTextOutput.lightcyan;
const lightred     = uefi.protocol.SimpleTextOutput.lightred;
const lightmagenta = uefi.protocol.SimpleTextOutput.lightmagenta;
const yellow       = uefi.protocol.SimpleTextOutput.yellow;
const white        = uefi.protocol.SimpleTextOutput.white;

fn setColor(color: u8) void {
    _ = uefi.system_table.con_out.?.setAttribute(color);
}

// Scratch buffers for formatting/converting to utf16
var buf: [256]u8 = undefined;
var wbuf: [256]u16 = undefined;

pub fn print(msg: []const u8) void {
    const len = std.unicode.utf8ToUtf16Le(&wbuf, msg) catch unreachable;
    wbuf[len] = 0;
    _ = uefi.system_table.con_out.?.outputString(@ptrCast(wbuf[0..len]));
}

pub fn printf(comptime format: []const u8, args: anytype) void {
    const fmtbuf = std.fmt.bufPrint(&buf, format, args) catch unreachable;
    print(fmtbuf);
}

pub fn printPrefix(prefix: []const u8, color: u8) void {
    setColor(color);
    print(prefix);
    setColor(white);
}

pub fn panicf(comptime format: []const u8, args: anytype) void {
    printPrefix("[panic] ", lightred);
    printf(format, args);
    print("\n\r");
}

pub fn panic(msg: []const u8) void {
    printPrefix("[panic] ", lightred);
    print(msg);
    print("\n\r");
}

pub fn errf(comptime format: []const u8, args: anytype) void {
    printPrefix("[error] ", red);
    printf(format, args);
    print("\n\r");
}

pub fn err(msg: []const u8) void {
    printPrefix("[error] ", red);
    print(msg);
    print("\n\r");
}

pub fn infof(comptime format: []const u8, args: anytype) void {
    printPrefix("[info] ", cyan);
    printf(format, args);
    print("\n\r");
}

pub fn info(msg: []const u8) void {
    printPrefix("[info] ", cyan);
    print(msg);
    print("\n\r");
}
