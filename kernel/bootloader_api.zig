pub const BootloaderApi = packed struct {
    fb_base: [*]u32,
    fb_width: u16,
    fb_height: u16,
    fb_bytes_per_line: u16,
    fb_bytes_per_pixel: u32,
};
