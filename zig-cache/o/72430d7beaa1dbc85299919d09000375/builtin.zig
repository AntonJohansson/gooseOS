usingnamespace @import("std").builtin;
/// Deprecated
pub const arch = Target.current.cpu.arch;
/// Deprecated
pub const endian = Target.current.cpu.arch.endian();
pub const output_mode = OutputMode.Exe;
pub const link_mode = LinkMode.Static;
pub const is_test = false;
pub const single_threaded = false;
pub const abi = Abi.none;
pub const cpu: Cpu = Cpu{
    .arch = .x86_64,
    .model = &Target.x86.cpu.x86_64,
    .features = Target.x86.featureSet(&[_]Target.x86.Feature{
        .@"64bit",
        .@"cmov",
        .@"cx8",
        .@"fxsr",
        .@"idivq_to_divl",
        .@"macrofusion",
        .@"mmx",
        .@"nopl",
        .@"slow_3ops_lea",
        .@"slow_incdec",
        .@"sse",
        .@"sse2",
        .@"vzeroupper",
        .@"x87",
    }),
};
pub const os = Os{
    .tag = .freestanding,
    .version_range = .{ .none = {} }
};
pub const object_format = ObjectFormat.elf;
pub const mode = Mode.ReleaseFast;
pub const link_libc = false;
pub const link_libcpp = false;
pub const have_error_return_tracing = false;
pub const valgrind_support = false;
pub const position_independent_code = true;
pub const strip_debug_info = false;
pub const code_model = CodeModel.default;
