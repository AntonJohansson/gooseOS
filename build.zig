const std = @import("std");
const Target = std.Target;
const CrossTarget = std.zig.CrossTarget;

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    // Build the bootloader
    const bootloader = b.addExecutable(.{
        .name = "bootx64",
        .root_source_file = .{ .path = "bootloader/efi_main.zig" },
        .target = b.resolveTargetQuery(.{
            .cpu_arch = Target.Cpu.Arch.x86_64,
            .os_tag = Target.Os.Tag.uefi,
            .abi = Target.Abi.msvc,
        }),
        .optimize = optimize,
    });
    bootloader.pie = true;
    _ = b.installArtifact(bootloader);

    // Build the kernel
    const kernel = b.addExecutable(.{
        .name = "kernel.elf",
        .root_source_file = .{ .path = "kernel/kernel_main.zig" },
        .target = b.resolveTargetQuery(.{
            .cpu_arch = Target.Cpu.Arch.x86_64,
            .os_tag = Target.Os.Tag.freestanding,
            .abi = Target.Abi.gnuabi64,
        }),
        .optimize = optimize,
    });
    kernel.setLinkerScriptPath(.{ .path = "kernel/kernel.ld" });
    kernel.pie = true;
    _ = b.installArtifact(kernel);
    b.default_step.dependOn(&kernel.step);

    // Post build command
    const cmd_img = b.addSystemCommand(&[_][]const u8{ "sh", "build_image.sh" });
    cmd_img.step.dependOn(&bootloader.step);
    cmd_img.step.dependOn(&kernel.step);

    b.default_step.dependOn(&cmd_img.step);

    const cmd_run = b.addSystemCommand(&[_][]const u8{ "sh", "run_qemu.sh" });
    cmd_run.step.dependOn(&cmd_img.step);
    const run_step = b.step("run", "run");
    run_step.dependOn(&cmd_run.step);
}
