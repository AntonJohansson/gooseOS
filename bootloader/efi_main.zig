const std  = @import("std");
const uefi = std.os.uefi;

const elf = @import("elf.zig");
usingnamespace @import("printf.zig");

const L = std.unicode.utf8ToUtf16LeStringLiteral;

const kernel_filename = "kernel.elf";
var boot_services: *uefi.tables.BootServices = undefined;

fn loadFile(filename: [*:0]const u16) ?*uefi.protocols.FileProtocol {
    var status: uefi.Status = undefined;

    var image: *uefi.protocols.LoadedImageProtocol = undefined;
    status = boot_services.handleProtocol(uefi.handle, &uefi.protocols.LoadedImageProtocol.guid, @ptrCast(*?*c_void, &image));
    if (status != uefi.Status.Success) {
        printf("[error] loadFile: uefi failed to handle image protocol, returned {}\n\r", .{status});
        return null;
    }

    var fs: *uefi.protocols.SimpleFileSystemProtocol = undefined;
    status = boot_services.handleProtocol(image.device_handle.?, &uefi.protocols.SimpleFileSystemProtocol.guid, @ptrCast(*?*c_void, &fs));
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
    printf("Loading kernel from {}\n\r", .{kernel_filename});

    const kernel_file = loadFile(L(kernel_filename)) orelse {
        print("[error] Failed to load kernel, exiting\n\r");
        return;
    };

    var header: elf.Elf64_Ehdr = undefined;
    {
        var file_info_size: u64 = 0;
        var file_info: *uefi.protocols.FileInfo = undefined;
        var status: uefi.Status = undefined;

        // For some reason the FileProtocol guid and FileInfo guid are the same.
        status = kernel_file.get_info(&uefi.protocols.FileProtocol.guid, &file_info_size, null);
    }
}
