// RGBA8
const Framebuffer = extern struct {
    base: [*]align(4) u8,
    size: u32,
    width: u32,
    height: u32,
    pps: u32,
};

fn pixel(fb: Framebuffer, x: usize, y: usize, color: u32) void {
    const p = @as([*]u32, @ptrCast(fb.base)) + fb.pps * y + x;
    p[0] = color;
}

export fn kernel_main(framebuffer: Framebuffer) callconv(.Win64) void {
    for (0..framebuffer.height) |y| {
        for (0..framebuffer.width) |x| {
            pixel(framebuffer, x, y, 0xff0000);
        }
    }
}
