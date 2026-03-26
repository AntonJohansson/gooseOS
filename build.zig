const std = @import("std");
const Target = std.Target;
const CrossTarget = std.zig.CrossTarget;

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    // Build the bootloader
    // const bootloader = b.addExecutable(.{
    //     .name = "bootx64",
    //     .root_source_file = .{ .path = "bootloader/uefi/efi_main.zig" },
    //     .target = b.resolveTargetQuery(.{
    //         .cpu_arch = Target.Cpu.Arch.x86_64,
    //         .os_tag = Target.Os.Tag.uefi,
    //         .abi = Target.Abi.msvc,
    //     }),
    //     .optimize = optimize,
    // });
    // bootloader.pie = true;
    // _ = b.installArtifact(bootloader);

    const bootloader_api = b.createModule(.{
        .root_source_file = b.path("kernel/bootloader_api.zig"),
        .target = b.resolveTargetQuery(.{
            .cpu_arch = Target.Cpu.Arch.x86_64,
            .os_tag = Target.Os.Tag.freestanding,
            .abi = Target.Abi.gnuabi64,
        }),
        .optimize = optimize,
    });

    // Build kernel assembly
    const cmd_isrs = b.addSystemCommand(&[_][]const u8{ "nasm", "-f", "elf64", "-o" });
    const out_isrs = cmd_isrs.addOutputFileArg("isrs.o");
    cmd_isrs.addFileArg(b.path("kernel/isrs.s"));

    // Build the kernel
    const kernel = b.addExecutable(.{
        .name = "kernel.elf",
        .root_module = b.createModule(.{
            .root_source_file = b.path("kernel/kernel_main.zig"),
            .target = b.resolveTargetQuery(.{
                .cpu_arch = .x86_64,
                .os_tag = .freestanding,
                .abi = .gnuabi64,
            }),
            .optimize = .ReleaseSmall,
            .code_model = .kernel,
        }),
        // Custom x86 backend doesn't respect linker script
        .linkage = .static,
        .use_llvm = true,
    });
    kernel.root_module.addImport("bootloader_api", bootloader_api);
    kernel.root_module.addObjectFile(out_isrs);
    kernel.setLinkerScript(b.path("kernel/kernel.ld"));
    //kernel.pie = true;
    const kernel_install_step = &b.addInstallArtifact(kernel, .{}).step;

    // Build tools
    const tool_ext = b.addExecutable(.{
        .name = "extract_elf_info",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/extract_elf_info.zig"),
            .target = target,
            .optimize = .Debug,
        }),
    });
    tool_ext.root_module.addImport("bootloader_api", bootloader_api);
    b.installArtifact(tool_ext);

    // Font editor
    const font_api = b.createModule(.{
        .root_source_file = b.path("kernel/font.zig"),
        .target = target,
        .optimize = optimize,
    });
    const fe = b.addExecutable(.{
        .name = "fonteditor",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/fonteditor.zig"),
            .target = target,
            .optimize = .Debug,
        }),
    });
    fe.root_module.addImport("font", font_api);
    fe.linkLibC();
    fe.linkSystemLibrary("raylib");
    const fe_run = b.addRunArtifact(fe);
    const fe_cmd = b.step("run-fonteditor", "");
    fe_cmd.dependOn(&fe_run.step);

    const boot_img: []u8 = @constCast(b.getInstallPath(.bin, "boot.img"));

    const tool_ext_run = b.addRunArtifact(tool_ext);
    tool_ext_run.argv.append(b.allocator, .{
        .bytes = @constCast(b.getInstallPath(.bin, kernel.name)),
    }) catch unreachable;
    tool_ext_run.argv.append(b.allocator, .{
        .bytes = @constCast("bootloader/bios/x86_64/stage0.s"),
    }) catch unreachable;
    tool_ext_run.argv.append(b.allocator, .{
        .bytes = @constCast("bootloader/bios/x86_64/stage1.s"),
    }) catch unreachable;
    tool_ext_run.argv.append(b.allocator, .{
        .bytes = boot_img,
    }) catch unreachable;
    tool_ext_run.argv.append(b.allocator, .{
        .bytes = @constCast(b.getInstallPath(.bin, "generated-stage-0.s")),
    }) catch unreachable;
    tool_ext_run.argv.append(b.allocator, .{
        .bytes = @constCast(b.getInstallPath(.bin, "generated-stage-1.s")),
    }) catch unreachable;
    tool_ext_run.argv.append(b.allocator, .{
        .bytes = @constCast(b.getInstallPath(.bin, "kernel.bin")),
    }) catch unreachable;
    tool_ext_run.argv.append(b.allocator, .{
        .bytes = @constCast(b.getInstallPath(.bin, "gdb.x")),
    }) catch unreachable;

    tool_ext_run.step.dependOn(&tool_ext.step);
    tool_ext_run.step.dependOn(kernel_install_step);

    b.getInstallStep().dependOn(&tool_ext_run.step);

    {
        const cmd = runQemu(b, boot_img);
        cmd.step.dependOn(&tool_ext_run.step);
        const run_step = b.step("run-qemu", "");
        run_step.dependOn(&cmd.step);
    }
    {
        const qemu_cmd = runQemuGdb(b, boot_img);
        qemu_cmd.step.dependOn(&tool_ext_run.step);
        const qemu_run_step = b.step("run-qemu-gdb", "");
        qemu_run_step.dependOn(&qemu_cmd.step);
    }
    {
        const cmd = runBochs(b, boot_img);
        cmd.step.dependOn(&tool_ext_run.step);
        const run_step = b.step("run-bochs", "");
        run_step.dependOn(&cmd.step);
    }
}

fn runQemu(b: *std.Build, boot_img: []u8) *std.Build.Step.Run {
    const cmd = b.addSystemCommand(&[_][]const u8{
        "qemu-system-x86_64",
        "-fda",
        boot_img,
        "-d",
        "int,mmu",
        "-vga",
        "virtio",
        "-m",
        "256M",
        "-cpu",
        "qemu64",
        "-no-reboot",
    });
    return cmd;
}

fn runQemuGdb(b: *std.Build, boot_img: []u8) *std.Build.Step.Run {
    const cmd = b.addSystemCommand(&[_][]const u8{
        "qemu-system-x86_64",
        "-d",
        "int,mmu",
        "-fda",
        boot_img,
        "-vga",
        "virtio",
        "-m",
        "256M",
        "-cpu",
        "qemu64",
        "-no-reboot",
        "-s",
        "-S",
    });
    return cmd;
}

fn runBochs(b: *std.Build, boot_img: []u8) *std.Build.Step.Run {
    const cmd = b.addSystemCommand(&[_][]const u8{
        "bochs",
        "-n",
        "megs:",
        "128",
        "romimage:",
        "file=/usr/share/bochs/BIOS-bochs-legacy, address=0xffff0000",
        "vgaromimage:",
        "file=/usr/share/bochs/VGABIOS-lgpl-latest",
        "floppya:",
        b.fmt("1_44={s}, status=inserted", .{boot_img}),
        "boot:",
        "floppy",
        "mouse:",
        "enabled=0",
        "display_library:",
        "x, options=\"gui_debug\"",
    });
    return cmd;
}
