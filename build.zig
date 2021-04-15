const Builder = @import("std").build.Builder;
const Target = @import("std").Target;
const CrossTarget = @import("std").zig.CrossTarget;

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
    b.default_step.dependOn(&bootloader_exe.step);

    // Build the bootloader
    const kernel_exe = b.addExecutable("kernel.elf", "kernel/kernel_main.zig");
    kernel_exe.setBuildMode(b.standardReleaseOptions());
    kernel_exe.setTarget(CrossTarget{
        .cpu_arch = Target.Cpu.Arch.x86_64,
        .os_tag = Target.Os.Tag.freestanding,
        .abi = Target.Abi.none,
    });
    kernel_exe.setLinkerScriptPath("kernel/kernel.ld");
    kernel_exe.force_pic = true;
    kernel_exe.setOutputDir("bin");
    b.default_step.dependOn(&kernel_exe.step);
}
