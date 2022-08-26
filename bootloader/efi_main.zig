const std  = @import("std");
const assert = std.debug.assert;
const uefi = std.os.uefi;

const elf = std.elf;
const print  = @import("printf.zig").print;
const printf = @import("printf.zig").printf;

const L = std.unicode.utf8ToUtf16LeStringLiteral;

const kernel_filename = "kernel.elf";
var boot_services: *uefi.tables.BootServices = undefined;

// Loads a file from the bootable image
fn loadFile(filename: [*:0]const u16) ?*uefi.protocols.FileProtocol {
    var status: uefi.Status = undefined;

    var image: *uefi.protocols.LoadedImageProtocol = undefined;
    status = boot_services.handleProtocol(uefi.handle, &uefi.protocols.LoadedImageProtocol.guid, @ptrCast(*?*anyopaque, &image));
    if (status != uefi.Status.Success) {
        printf("[error] loadFile: uefi failed to handle image protocol, returned {}\n\r", .{status});
        return null;
    }

    var fs: *uefi.protocols.SimpleFileSystemProtocol = undefined;
    status = boot_services.handleProtocol(image.device_handle.?, &uefi.protocols.SimpleFileSystemProtocol.guid, @ptrCast(*?*anyopaque, &fs));
    if (status != uefi.Status.Success) {
        printf("[error] loadFile: uefi failed to handle filesystem protocol, returned {}\n\r", .{status});
        return null;
    }

    var dir: *const uefi.protocols.FileProtocol = undefined;
    status = fs.openVolume(&dir);
    if (status != uefi.Status.Success) {
        printf("[error] loadFile: uefi failed to open volume, returned {}\n\r", .{status});
        return null;
    }

    var file: *uefi.protocols.FileProtocol = undefined;
    status = dir.open(&file, filename, uefi.protocols.FileProtocol.efi_file_mode_read, uefi.protocols.FileProtocol.efi_file_read_only);
    if (status != uefi.Status.Success) {
        printf("[error] loadFile: uefi failed to open file, returned {}\n\r", .{status});
        return null;
    }

    return file;
}

pub fn main() void {
    boot_services = uefi.system_table.boot_services.?;

    print("Started bootloader\n\r");
    printf("Loading kernel from {s}\n\r", .{kernel_filename});

    const kernel_file = loadFile(L(kernel_filename)) orelse {
        print("[error] Failed to load kernel, exiting\n\r");
        return;
    };

    const pool = std.heap.ArenaAllocator.init(uefi.pool_allocator).allocator();
    _ = pool;

    // Load kernel elf file
    var header: elf.Header = undefined;
    header = elf.Header.read(kernel_file) catch unreachable;

    // Verify kernel elf file
    if (!header.is_64)
        print("[error] kernel not 64-bit!\n\r");
    if (header.machine != ._X86_64)
        print("[error] kernel not for x86_64!\n\r");

    // Find elf segment where main lies
    var segment: u64 = 0;
    var it = header.program_header_iterator(kernel_file);
    while (it.next() catch unreachable) |p| {
        if (p.p_type == elf.PT_LOAD) {
            printf("{}\n\r", .{p});
            var pages = (p.p_memsz + 4096 - 1) / 4096;
            printf("Allocating {} pages for kernel.\n\r", .{pages});
            var status = uefi.system_table.boot_services.?.allocatePages(.AllocateAnyPages, .LoaderData, pages, @ptrCast(*[*]align(4096) u8, &segment));
            assert(status == .Success);
            printf("Kernel resides at 0x{x}\n\r", .{segment});

            kernel_file.seekableStream().seekTo(p.p_offset) catch unreachable;
            var size = p.p_filesz;
            status = kernel_file.read(&size, @intToPtr([*]u8, segment));
            assert(status == .Success);
            break;
        }
    }

    // Initialize GOP, framebuffer and font

    // Setup memory map

    // Call kernel main
    const kernel_main = @ptrCast(fn () callconv(.C) i32, @intToPtr(*u64, segment + header.entry));
    _ = kernel_main;
    const j = kernel_main();
    printf("Kernel returned {}\n\r", .{j});
    print("Finished\n\r");

    var i: usize = 0;
    while (i < 1000000000) {i += 1;}
}
