const font = @import("font.zig").font;
const std = @import("std");

pub var width: u16 = 0;
pub var height: u16 = 0;
pub var framebuffer: [*]u32 = undefined;
pub var margin_left: u16 = 10;
pub var margin_top: u16 = 20;
pub var spacing_line: u16 = 8;

var current_line: u16 = 0;

fn pixel(x: usize, y: usize, color: u32) void {
    framebuffer[width * y + x] = color;
}

fn char(c: u8, scale: usize, x: usize, y: usize, color: u32) void {
    for (0..font.height) |j| {
        for (0..font.width) |i| {
            if (font.chars[c-33][j][i] == 1) {
                pixel(x + scale * i, y + scale * j - font.offsets[c-33], color);
            }
        }
    }
}

fn text(str: []const u8, scale: usize, start_x: usize, start_y: usize, color: u32) void {
    var x = start_x;
    const y = start_y;
    for (str) |c| {
        char(c, scale, x, y, color);
        x += font.width + 4;
    }
}

pub fn log(str: []const u8) void {
    text(str, 1, margin_left, margin_top + (spacing_line + font.height)*current_line, 0xff00ff);
    current_line += 1;
}

pub fn log_fmt(comptime fmt: []const u8, args: anytype) void {
    var buf: [128]u8 = undefined;
    const str = std.fmt.bufPrint(&buf, fmt, args) catch {
        return;
    };
    log(str);
}
