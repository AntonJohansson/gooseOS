const std = @import("std");
const builtin = @import("builtin");

const assert = if (builtin.mode != .Debug) std.debug.assert else slow_assert;
fn slow_assert(ok: bool) void {
    if (!ok) panic("assert failed");
}

const uefi = std.os.uefi;
const elf = std.elf;
const log = @import("log.zig");

const bootloader_name = "gooseloader";
const kernel_filename = "kernel.elf";
const major = 0;
const minor = 0;
const patch = 1;
const page_size = 4096;

const L = std.unicode.utf8ToUtf16LeStringLiteral;
var boot_services: *uefi.tables.BootServices = undefined;

// RGBA8
const Framebuffer = extern struct {
    base: [*]align(4) u8,
    size: u32,
    width: u32,
    height: u32,
    pps: u32,
};

// Loads a file from the bootable image
fn loadFile(filename: [*:0]const u16) ?*uefi.protocol.File {
    var status: uefi.Status = undefined;

    var image: *uefi.protocol.LoadedImage = undefined;
    status = boot_services.handleProtocol(uefi.handle, &uefi.protocol.LoadedImage.guid, @ptrCast(&image));
    if (status != uefi.Status.Success) {
        panicf("({})) uefi failed to handle image protocol", .{status});
        return null;
    }

    var fs: *uefi.protocol.SimpleFileSystem = undefined;
    status = boot_services.handleProtocol(image.device_handle.?, &uefi.protocol.SimpleFileSystem.guid, @ptrCast(&fs));
    if (status != uefi.Status.Success) {
        panicf("({})) uefi failed to handle filesystem protocol", .{status});
        return null;
    }

    var dir: *const uefi.protocol.File = undefined;
    status = fs.openVolume(&dir);
    if (status != uefi.Status.Success) {
        panicf("({})) uefi failed to open volume", .{status});
        return null;
    }

    var file: *uefi.protocol.File = undefined;
    status = dir.open(&file, filename, uefi.protocol.File.efi_file_mode_read, uefi.protocol.File.efi_file_read_only);
    if (status != uefi.Status.Success) {
        panicf("({})) uefi failed to open file", .{status});
        return null;
    }

    return file;
}

pub fn main() void {
    log.infof("{s} {}.{}.{} ({s})", .{ bootloader_name, major, minor, patch, @tagName(builtin.mode) });

    boot_services = uefi.system_table.boot_services.?;
    var arena_state = std.heap.ArenaAllocator.init(uefi.pool_allocator);
    const pool = arena_state.allocator();
    _ = pool;

    log.infof("Loading kernel from {s}", .{kernel_filename});
    const kernel_file = loadFile(L(kernel_filename)) orelse {
        panicf("Failed to load kernel binary {s}", .{kernel_filename});
    };

    // Parse and verify elf header
    const header = elf.Header.read(kernel_file) catch |err| {
        panicf("Failed to parse kernel elf header ({})", .{err});
    };
    if (!header.is_64) {
        panic("kernel not 64-bit!");
    }
    if (header.machine != .X86_64) {
        panic("kernel not for x86_64!");
    }

    // Find elf segment where main lies
    var segment: u64 = 0;
    const load_header = blk: {
        var it = header.program_header_iterator(kernel_file);
        while (it.next() catch |err| {
            panicf("Failed to find next program header ({})", .{err});
        }) |p| {
            if (p.p_type == elf.PT_LOAD and p.p_flags & elf.PF_X == 1)
                break :blk p;
        }
        panic("Failed to find kernel PT_LOAD header");
    };

    {
        // TODO(anjo): Get pagesize from uefi
        const pages = roundToPageSize(load_header.p_memsz);
        var status = uefi.system_table.boot_services.?.allocatePages(.AllocateAnyPages, .LoaderCode, pages, @ptrCast(&segment));
        assert(status == .Success);
        kernel_file.seekableStream().seekTo(load_header.p_offset) catch unreachable;
        var size = load_header.p_filesz;
        status = kernel_file.read(&size, @ptrFromInt(segment));
        assert(status == .Success);
        log.infof("Kernel address: 0x{x}", .{segment});
        log.infof("Kernel size: {}", .{load_header.p_memsz});
        log.infof("Allocated {} pages for kernel", .{pages});
        log.infof("segment vaddr {}", .{load_header.p_vaddr});
        log.infof("segment paddr {}", .{load_header.p_paddr});
        log.infof("segment off {}", .{load_header.p_offset});
        log.infof("entry {}", .{header.entry});
    }

    // Initialize GOP, framebuffer and font
    var framebuffer: Framebuffer = undefined;
    {
        var status: uefi.Status = undefined;

        var gop: ?*uefi.protocol.GraphicsOutput = null;
        status = boot_services.locateProtocol(&uefi.protocol.GraphicsOutput.guid, null, @ptrCast(&gop));
        //status = boot_services.handleProtocol(uefi.handle, &uefi.protocol.GraphicsOutput.guid, @ptrCast(&gop));
        if (status != uefi.Status.Success or gop == null) {
            panicf("({}) uefi failed to handle GOP protocol", .{status});
        }

        // We just use the native mode here

        //status = gop.?.queryMode(gop.?.mode.mode, &gop.?.mode.size_of_info, &gop.?.mode.info);
        //if (status != uefi.Status.Success) {
        //    panicf("({}) Failed to query graphics mode", .{status});
        //}

        framebuffer.base = @ptrFromInt(gop.?.mode.frame_buffer_base);
        framebuffer.size = @intCast(gop.?.mode.frame_buffer_size);
        framebuffer.width = @intCast(gop.?.mode.info.horizontal_resolution);
        framebuffer.height = @intCast(gop.?.mode.info.vertical_resolution);
        framebuffer.pps = gop.?.mode.info.pixels_per_scan_line;
    }

    log.info("Framebuffer:");
    log.infof("  address:    0x{*}", .{framebuffer.base});
    log.infof("  size:       {}", .{framebuffer.size});
    log.infof("  resolution: {}x{}", .{ framebuffer.width, framebuffer.height });
    log.infof("  pps:        {}", .{framebuffer.pps});

    // Setup memory map
    var mm: [*]uefi.tables.MemoryDescriptor = undefined;
    var mm_size: usize = 0;
    var mm_key: usize = undefined;
    var descriptor_size: usize = undefined;
    var descriptor_version: u32 = undefined;
    {
        _ = boot_services.getMemoryMap(&mm_size, mm, &mm_key, &descriptor_size, &descriptor_version);
        // Worst case, the following allocation would add another descriptor entry
        mm_size += 1;
        _ = boot_services.allocatePool(.LoaderData, mm_size, @ptrCast(&mm));
        _ = boot_services.getMemoryMap(&mm_size, mm, &mm_key, &descriptor_size, &descriptor_version);
    }

    // Call kernel main
    const kernel_main: *const fn (framebuffer: Framebuffer) void = @ptrFromInt(segment + header.entry - load_header.p_vaddr);
    kernel_main(framebuffer);

    while (true) {
        asm volatile ("pause");
    }
}

fn roundToPageSize(size: usize) usize {
    return (size + page_size - 1) / page_size;
}

fn panic(msg: []const u8) noreturn {
    log.panic(msg);
    std.process.exit(255);
}

fn panicf(comptime format: []const u8, args: anytype) noreturn {
    log.panicf(format, args);
    std.process.exit(255);
}
