const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
});

var font = @import("font").font;

pub fn main() !void {
    c.SetTargetFPS(60);
    c.InitWindow(800, 600, "fonteditor");
    defer c.CloseWindow();

    var gpa_state = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa_state.deinit() != .ok) @panic("leak");
    const gpa = gpa_state.allocator();

    var selected: usize = 0;
    var drawing: bool = false;
    const l = 20;
    while (!c.WindowShouldClose()) {

        if (!drawing) {
            if (c.IsKeyPressed(c.KEY_Q)) {
                selected = (selected + font.chars.len-1) % font.chars.len;
            }
            if (c.IsKeyPressed(c.KEY_W)) {
                selected = (selected + 1) % font.chars.len;
            }
        } else {
            const w: usize  = @intCast(@divTrunc(@max(c.GetMouseX(), 0), (l)));
            const h: usize  = @intCast(@divTrunc(@max(c.GetMouseY(), 0), (l)));
            if (c.IsMouseButtonDown(c.MOUSE_BUTTON_LEFT)) {
                if (w < font.width and h < font.height) {
                    font.chars[selected][h][w] = 1;
                }
            }
            if (c.IsMouseButtonDown(c.MOUSE_BUTTON_RIGHT)) {
                if (w < font.width and h < font.height) {
                    font.chars[selected][h][w] = 0;
                }
            }
            if (c.IsKeyPressed(c.KEY_Q)) {
                const i: usize = @intCast(font.offsets[selected]);
                font.offsets[selected] = @truncate((i + (font.height-1)) % font.height);
            }
            if (c.IsKeyPressed(c.KEY_W)) {
                const i: usize = @intCast(font.offsets[selected]);
                font.offsets[selected] = @truncate((i + 1) % font.height);
            }
        }
        if (c.IsKeyPressed(c.KEY_F)) {
            drawing = !drawing;
        }

        c.BeginDrawing();
        c.ClearBackground(c.BLACK);
        if (!drawing) {
            for (0..font.chars.len) |i| {

                var set = false;
                for (font.chars[i]) |row| {
                    for (row) |j| {
                        if (j != 0) {
                            set = true;
                            break;
                        }
                    }
                }

                const x: usize = (i % 10 + 1) * 32;
                const y: usize = (@divFloor(i, 10)+1) * 64;

                if (set) {
                    const scale = 2;
                    for (0..font.height) |h| {
                        for (0..font.width) |w| {
                            const color = if (i == selected) c.BLUE else c.GREEN;
                            if (font.chars[i][h][w] == 1) {
                                c.DrawRectangle(@intCast(x + scale*w), @intCast(y + scale*h), scale, scale, color);
                            }
                        }
                    }
                } else {
                    const str = [2]u8{@truncate(33+i),0};
                    const color = if (i == selected) c.BLUE else c.RED;
                    c.DrawText(&str, @intCast(x), @intCast(y), 24, color);
                }
            }
        } else {
            const mw: usize = @intCast(font.width);
            const mh: usize = @intCast(font.height);
            for (0..font.height) |h| {
                c.DrawLine(0, @intCast(l*h), @intCast(l*mw), @intCast(l*h), c.GRAY);
            }
            for (0..font.width) |w| {
                c.DrawLine(@intCast(l*w), 0, @intCast(l*w), @intCast(l*mh), c.GRAY);
            }
            for (0..font.height) |h| {
                for (0..font.width) |w| {
                    if (font.chars[selected][h][w] == 1) {
                        c.DrawRectangle(@intCast(l*w), @intCast(l*h), l, l, c.WHITE);
                    } else if (h == font.offsets[selected]) {
                        c.DrawRectangle(@intCast(l*w), @intCast(l*h), l, l, c.GRAY);
                    }
                }
            }
        }
        c.EndDrawing();
    }

    _ = gpa;
    var buf: [1024]u8 = undefined;

    const fd = try std.fs.cwd().createFile("kernel/font.zig", .{});
    defer fd.close();
    var fw = fd.writer(&buf);
    const wi = &fw.interface;
    try wi.writeAll("const format = @import(\"font-format.zig\");\n");
    try wi.print("pub const font = format.Font({}, {}, {}){{\n", .{font.width, font.height, font.chars.len});

    try wi.writeAll("    .offsets = .{");
    try wi.writeAll("        ");
    for (font.offsets, 0..) |o, i| {
        try wi.print("{}", .{o});
        if (i < font.offsets.len-1) {
            try wi.writeAll(", ");
        }
    }
    try wi.writeAll("},\n");

    try wi.writeAll("    .chars = .{\n");
    for (font.chars, 0..) |data, char| {
        try wi.print("        .{{ // {c}\n", .{@as(u8, @intCast(33+char))});
        for (data) |rows| {
            try wi.writeAll("            .{");
            for (rows, 0..) |d, i| {
                try wi.print("{}", .{d});
                if (i < rows.len-1) {
                    try wi.writeAll(", ");
                }
            }
            try wi.writeAll("},\n");
        }
        try wi.writeAll("        },\n");
    }
    try wi.writeAll("    },\n");

    try wi.writeAll("};\n");
    try wi.flush();

    return;
}
