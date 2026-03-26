const std = @import("std");
const bootloader_api = @import("bootloader_api");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const args = std.process.argsAlloc(allocator) catch {
        std.log.err("Failed to process commandline arguments!", .{});
        return;
    };
    defer std.process.argsFree(allocator, args);

    if (args.len != 9) {
        std.log.err("Usage extract_elf_info [elf] [out.s]", .{});
        std.process.exit(255);
    }

    const input_elf = args[1];
    const input_stage0 = args[2];
    const input_stage1 = args[3];
    const output_boot = args[4];
    const output_stage0_gen = args[5];
    const output_stage1_gen = args[6];
    const output_bin = args[7];
    const gdb_x = args[8];

    const bin_stage0 = try std.fs.path.join(allocator, &[_][]const u8{ std.fs.path.dirname(output_boot).?, "stage0.bin" });

    const bin_stage1 = try std.fs.path.join(allocator, &[_][]const u8{ std.fs.path.dirname(output_boot).?, "stage1.bin" });

    const bootloader_origin = 0x7c00;
    const sector_size = 512;
    const segment_size = 0xffff;
    const stage0_base_sector = 0;
    const stage1_base_sector = 1;
    var kernel_base_sector: usize = undefined;
    var kernel_segments: usize = 0;

    //
    // Extract elf info from kernel into generades .asm constants
    //
    {
        std.log.info("Finding kernel LOAD sections", .{});
        const input_file = std.fs.cwd().openFile(input_elf, .{}) catch |err| {
            std.log.err("Failed to open file: {s} ({})", .{ input_elf, err });
            return;
        };
        defer input_file.close();

        const buffer = try allocator.alloc(u8, (try input_file.stat()).size);
        var reader = input_file.reader(buffer);

        const header = try std.elf.Header.read(&reader.interface);

        {
            const fd = std.fs.cwd().createFile(gdb_x, .{}) catch |err| {
                std.log.err("Failed to open file: {s} ({})", .{ gdb_x, err });
                return;
            };
            defer fd.close();
            var writer = fd.writer(buffer);
            const wi = &writer.interface;
            try wi.writeAll("target remote ::1:1234\n");
            try wi.print("b *0x{x}\n", .{header.entry});
            try wi.writeAll("c\n");
            try wi.writeAll("lay r\n");
            try wi.flush();
        }

        // Look up start and end address of LOAD segments
        var start_addr: usize = std.math.maxInt(usize);
        var end_addr: usize = 0;
        {
            var it = header.iterateProgramHeaders(&reader);
            while (try it.next()) |p| {
                if (p.p_type != std.elf.PT_LOAD) {
                    continue;
                }
                if (p.p_vaddr < start_addr) {
                    start_addr = p.p_vaddr;
                }
                if (p.p_vaddr + p.p_memsz > end_addr) {
                    end_addr = p.p_vaddr + p.p_memsz;
                }
            }
        }

        const kernel_mem_size = end_addr - start_addr;
        std.log.info("kernel size: {} KiB", .{kernel_mem_size / 1024});
        std.log.info("kernel start addr: 0x{x}", .{start_addr});
        std.log.info("kernel   end addr: 0x{x}", .{end_addr});
        if (start_addr < 1024 * 1024 or kernel_mem_size >= (0xffff * 16 + 0xffff)) {
            std.log.err("kernel not contained in [1MiB, 1MiB + 64KiB] region!", .{});
            std.process.exit(255);
        }

        {
            const file_bin = std.fs.cwd().createFile(output_bin, .{}) catch |err| {
                std.log.err("Failed to open file: {s} ({})", .{ output_bin, err });
                return;
            };
            defer file_bin.close();

            var it = header.iterateProgramHeaders(&reader);
            while (try it.next()) |p| {
                if (p.p_type != std.elf.PT_LOAD) {
                    continue;
                }

                const buf = try allocator.alloc(u8, @max(p.p_filesz, p.p_memsz));
                defer allocator.free(buf);

                var bytes_read: usize = 0;
                try input_file.seekTo(p.p_offset);
                bytes_read = try input_file.readAll(buf[0..p.p_filesz]);
                std.debug.assert(bytes_read == p.p_filesz);

                try file_bin.seekTo(p.p_vaddr - start_addr);
                try file_bin.writeAll(buf[0..p.p_filesz]);

                const diff = p.p_memsz - p.p_filesz;
                if (diff > 0) {
                    bytes_read = try input_file.readAll(buf[0..diff]);
                    std.debug.assert(bytes_read == diff);

                    var writer = file_bin.writerStreaming(buf);
                    const bytes_written = try writer.interface.splatByte(0, diff);
                    std.debug.assert(bytes_written == diff);
                }
            }
        }

        const kernel_segment: u16 = @min(@divFloor(start_addr, 16), 0xffff);
        const kernel_offset: u16 = @truncate(start_addr - @as(usize, @intCast(kernel_segment)) * 16);
        std.debug.assert(@as(usize, @intCast(kernel_segment)) * 16 + @as(usize, @intCast(kernel_offset)) == start_addr);

        const stage0_base = bootloader_origin;
        const stage1_base = bootloader_origin + sector_size;
        //var kernel_base: usize = undefined;

        const stage0_sectors = 1;
        var stage1_sectors: usize = undefined;
        kernel_segments = @divFloor(kernel_mem_size + segment_size - 1, segment_size);
        const kernel_sectors  = @divFloor(0xffff + sector_size - 1, sector_size);


        // Generate stage 1 defines
        {
            std.log.info("Generating stage 1 defines", .{});
            const file_asm = std.fs.cwd().createFile(output_stage1_gen, .{}) catch |err| {
                std.log.err("Failed to open file: {s} ({})", .{ output_stage1_gen, err });
                return;
            };
            defer file_asm.close();

            var writer = file_asm.writer(buffer);
            const wi = &writer.interface;
            try wi.print("%define stage1_base {}\n", .{stage1_base});
            try wi.print("%define kernel_segment {}\n", .{kernel_segment});
            try wi.print("%define kernel_offset {}\n", .{kernel_offset});
            try wi.print("%define kernel_entry {}\n", .{header.entry});
            try wi.print("%define kernel_sectors {}\n", .{kernel_sectors});
            try wi.print("%define kernel_segments {}\n", .{kernel_segments});

            inline for (@typeInfo(bootloader_api).@"struct".decls) |d| {
                const f = @field(bootloader_api, d.name);
                const ti = @typeInfo(f);

                var struct_size: usize = 0;
                inline for (ti.@"struct".fields) |child_f| {
                    switch (@typeInfo(child_f.type)) {
                        .int => |i| {
                            struct_size += i.bits;
                        },
                        .pointer => {
                            struct_size += 64;
                        },
                        else => @compileError("Unsupported bootloader api type " ++ @typeName(child_f.type)),
                    }
                }

                try wi.print("%define {s}_Size {}\n", .{ d.name, struct_size / 8 });
                try wi.print("struc {s}\n", .{d.name});

                inline for (ti.@"struct".fields) |child_f| {
                    switch (@typeInfo(child_f.type)) {
                        .int => |i| {
                            const size = switch (i.bits) {
                                8 => 'b',
                                16 => 'w',
                                32 => 'd',
                                64 => 'q',
                                else => @compileError("Unsupported int size " ++ i.bits),
                            };
                            try wi.print("    .{s} res{c} 1\n", .{ child_f.name, size });
                        },
                        .pointer => {
                            try wi.print("    .{s} res{c} 1\n", .{ child_f.name, 'q' });
                        },
                        else => @compileError("Unsupported bootloader api type " ++ @typeName(child_f.type)),
                    }
                }
                try wi.writeAll("endstruc\n");
            }
            try wi.flush();

            //const page_addr = 1024*1024 - 16*1024;
            //const page_segment: u16 = @min(@divFloor(page_addr, 16), 0xffff);
            //const page_offset: u16 = @truncate(page_addr - @as(usize, @intCast(page_segment))*16);
            //try writer.print("%define page_segment {}\n", .{page_segment});
            //try writer.print("%define page_offset {}\n", .{page_offset});
        }

        // Assemble stage 1
        {
            std.log.info("Assembling stage 1", .{});
            var proc = std.process.Child.init(&[_][]const u8{ "nasm", input_stage1, "-f", "bin", "-o", bin_stage1 }, allocator);
            try proc.spawn();
            _ = try proc.wait();
        }

        // Generate stage 0 defines
        {
            std.log.info("Generating stage 0 defines", .{});
            const file_asm = std.fs.cwd().createFile(output_stage0_gen, .{}) catch |err| {
                std.log.err("Failed to open file: {s} ({})", .{ output_stage0_gen, err });
                return;
            };
            defer file_asm.close();
            var writer = file_asm.writer(buffer);
            const wi = &writer.interface;

            const stage1 = try std.fs.cwd().openFile(bin_stage1, .{});
            defer stage1.close();
            const stat = try stage1.stat();
            stage1_sectors = divRound(stat.size, sector_size);
            kernel_base_sector = stage1_base_sector + stage1_sectors;

            try wi.print("%define sector_size {}\n", .{sector_size});
            try wi.print("%define reserved_sectors {}\n", .{stage0_sectors + stage1_sectors + kernel_sectors});
            try wi.print("%define stage0_base {}\n", .{stage0_base});
            try wi.print("%define stage1_base {}\n", .{stage1_base});
            try wi.print("%define kernel_base_sector {}\n", .{kernel_base_sector});

            try wi.print("%define stage0_sectors {}\n", .{stage0_sectors});
            try wi.print("%define stage1_sectors {}\n", .{stage1_sectors});
            try wi.flush();
        }

        // Assemble stage 0
        {
            std.log.info("Assembling stage 0", .{});
            var proc = std.process.Child.init(&[_][]const u8{ "nasm", input_stage0, "-f", "bin", "-o", bin_stage0 }, allocator);
            try proc.spawn();
            _ = try proc.wait();
        }
    }

    //
    // Assemble bootloader
    //
    {
        var buf0 = [_]u8{0} ** 512;
        var buf1: [512]u8 = undefined;
        var buf2: [512]u8 = undefined;
        var buf3: [512]u8 = undefined;

        const file_boot = std.fs.cwd().createFile(output_boot, .{}) catch |err| {
            std.log.err("Failed to open file: {s} ({})", .{ output_boot, err });
            return;
        };
        var file_boot_writer = file_boot.writerStreaming(&buf0);
        const wi = &file_boot_writer.interface;
        defer file_boot.close();

        // Zero out image
        try file_boot.seekTo(sector_size * 2880 - 1);
        try file_boot.writeAll("0");

        // Format image
        {
            var proc = std.process.Child.init(&[_][]const u8{ "mkfs.fat", "-F", "12", output_boot }, allocator);
            try proc.spawn();
            _ = try proc.wait();
        }

        const stage0 = try std.fs.cwd().openFile(bin_stage0, .{});
        const stage1 = try std.fs.cwd().openFile(bin_stage1, .{});
        const kernel = try std.fs.cwd().openFile(output_bin, .{});
        var stage0_reader = stage0.reader(&buf1);
        var stage1_reader = stage1.reader(&buf2);
        var kernel_reader = kernel.reader(&buf3);
        defer stage0.close();
        defer stage1.close();
        defer kernel.close();

        try file_boot.seekTo(0);
        try file_boot.seekTo(sector_size * stage0_base_sector);
        _ = try wi.sendFile(&stage0_reader, .unlimited);
        try file_boot.seekTo(sector_size * stage1_base_sector);
        _ = try wi.sendFile(&stage1_reader, .unlimited);

        // Zero out kernel memory, rounding to a segment
        try file_boot.seekTo(sector_size * kernel_base_sector + segment_size * kernel_segments);
        try file_boot.writeAll("0");

        try file_boot.seekTo(sector_size * kernel_base_sector);
        _ = try wi.sendFile(&kernel_reader, .unlimited);

        try wi.flush();
    }
}

fn divRound(val: usize, div: usize) usize {
    return @divFloor(val + div - 1, div);
}

fn roundToMultiple(val: usize, div: usize) usize {
    return div * divRound(val, div);
}
