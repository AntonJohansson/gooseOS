const std = @import("std");
const Builder = std.build.Builder;
const Target = std.Target;
const CrossTarget = std.zig.CrossTarget;

pub fn build(b: *Builder) void {
    // Build the bootloader
    const bootloader_exe = b.addExecutable("bootx64", "bootloader/efi_main.zig");
    bootloader_exe.setBuildMode(b.standardReleaseOptions());
    bootloader_exe.setTarget(CrossTarget{
        .cpu_arch = Target.Cpu.Arch.x86_64,
        .os_tag = Target.Os.Tag.uefi,
        .abi = Target.Abi.msvc,
    });
    bootloader_exe.force_pic = true;
    bootloader_exe.setOutputDir("bin");

    // Build the kernel
    const kernel_exe = b.addExecutable("kernel.elf", "kernel/kernel_main.zig");
    kernel_exe.setBuildMode(b.standardReleaseOptions());
    kernel_exe.setTarget(CrossTarget{
        .cpu_arch = Target.Cpu.Arch.x86_64,
        .os_tag = Target.Os.Tag.freestanding,
        .abi = Target.Abi.gnuabi64,
    });
    kernel_exe.setLinkerScriptPath(std.build.FileSource {.path = "kernel/kernel.ld"});
    kernel_exe.force_pic = true;
    kernel_exe.setOutputDir("bin");
    b.default_step.dependOn(&kernel_exe.step);

    // Post build command
    const cmd_img = b.addSystemCommand(&[_][]const u8{
        "sh", "build_image.sh"
    });
    cmd_img.step.dependOn(&bootloader_exe.step);
    cmd_img.step.dependOn(&kernel_exe.step);

    b.default_step.dependOn(&cmd_img.step);

    const cmd_run = b.addSystemCommand(&[_][]const u8{
        "sh", "run_qemu.sh"
    });
    cmd_run.step.dependOn(&cmd_img.step);
    const run_step = b.step("run", "run the stuff");
    run_step.dependOn(&cmd_run.step);

}
