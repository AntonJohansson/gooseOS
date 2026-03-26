pub fn Font(comptime w: usize, comptime h: usize, comptime num_chars: usize) type {
    return struct {
        width: u8 = w,
        height: u8 = h,
        offsets: [num_chars]u4 = .{h/2-1}**num_chars,
        chars: [num_chars][h][w]u1 = .{.{.{0}**w}**h}**num_chars,
    };
}
