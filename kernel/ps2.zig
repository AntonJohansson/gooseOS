const idt = @import("idt.zig");
const x86 = @import("x86.zig");
const console = @import("console.zig");

const reg_cmd  = 0x64;
const reg_data = 0x60;

const Scancodeset = enum(u2) {
    get_current = 0,
    set_1 = 1,
    set_2 = 2,
    set_3 = 3,
};

const ScancodeResponse= enum(u2) {
    raw_set_1 = 1,
    raw_set_2 = 2,
    raw_set_3 = 3,
    translated_set_1 = 0x43,
    translated_set_2 = 0x41,
    translated_set_3 = 0x3f,
};

const TypematicRate = packed struct(u3) {
    repeat_rate: u4, // 0 = 30 hz, 0b11111 = 2 hz
    delay: enum(u2) {
        delay_250ms  = 0b00,
        delay_500ms  = 0b01,
        delay_750ms  = 0b10,
        delay_1000ms = 0b11,
    },
    _always_0: u1 = 0,
};

const Key = enum(u64) {
    f1  = 0x05,
    f2  = 0x06,
    f3  = 0x04,
    f4  = 0x0c,
    f5  = 0x03,
    f6  = 0x0b,
    f7  = 0x83,
    f8  = 0x0a,
    f9  = 0x01,
    f10 = 0x09,
    f11 = 0x78,
    f12 = 0x07,

    tab = 0x0d,
    space = 0x29,
    enter = 0x5a,
    backspace = 0x66,
    capslock = 0x58,
    scrollock = 0x7e,
    numlock = 0x77,

    backtick = 0x0e,
    single_quote = 0x52,

    left_alt = 0x11,
    left_shift = 0x12,
    left_control = 0x14,
    right_shift = 0x59,
    right_alt = 0x11e0,
    right_control = 0x14e0,

    num0 = 0x45,
    num1 = 0x16,
    num2 = 0x1e,
    num3 = 0x26,
    num4 = 0x25,
    num5 = 0x2e,
    num6 = 0x36,
    num7 = 0x3d,
    num8 = 0x3e,
    num9 = 0x46,

    a = 0x1c,
    b = 0x32,
    c = 0x21,
    d = 0x23,
    e = 0x24,
    f = 0x2b,
    g = 0x34,
    h = 0x33,
    i = 0x43,
    j = 0x3b,
    k = 0x42,
    l = 0x4b,
    m = 0x3a,
    n = 0x31,
    o = 0x44,
    p = 0x4d,
    q = 0x15,
    r = 0x2d,
    s = 0x1b,
    t = 0x2c,
    u = 0x3c,
    v = 0x2a,
    x = 0x22,
    y = 0x35,
    z = 0x1a,
    w = 0x1d,

    period = 0x49,
    comma = 0x41,
    semicolon = 0x4c,

    slash = 0x4a,
    backslash = 0x5d,
    minus = 0x4e,
    equals = 0x55,

    left_angle_bracket = 0x54,
    right_angle_bracket = 0x5b,

    keypad_num0   = 0x70,
    keypad_num1   = 0x69,
    keypad_num2   = 0x72,
    keypad_num3   = 0x7a,
    keypad_num4   = 0x6b,
    keypad_num5   = 0x73,
    keypad_num6   = 0x74,
    keypad_num7   = 0x6c,
    keypad_num8   = 0x75,
    keypad_num9   = 0x7d,
    keypad_period = 0x71,
    keypad_plus   = 0x79,
    keypad_minus  = 0x7b,
    keypad_mul    = 0x7c,
    keypad_escape = 0x76,
    keypad_enter  = 0x5ae0,

    media_web_search     = 0x10e0,
    media_web_favourites = 0x18e0,
    media_web_refresh    = 0x20e0,
    media_web_stop       = 0x28e0,
    media_web_forward    = 0x30e0,
    media_web_back       = 0x38e0,
    media_web_home       = 0x3ae0,

    media_prev_track = 0x15e0,
    media_vol_down   = 0x21e0,
    media_vol_up     = 0x32e0,
    media_mute       = 0x23e0,
    media_calculator = 0x2be0,
    media_play_pause = 0x34e0,
    media_stop       = 0x3be0,
    media_my_computer = 0x40e0, 
    media_email       = 0x50e0,

    left_gui  = 0x1fe0,
    right_gui = 0x27e0,
    apps      = 0x2fe0,

    acpi_power = 0x37e0,
    acpi_sleep = 0x3fe0,
    acpi_wake  = 0x5ee0,

    end    = 0x69e0,
    home   = 0x6ce0,
    insert = 0x70e0,
    delete = 0x71e0,
    page_down = 0x7ae0,
    page_up   = 0x7de0,
    
    arrow_left  = 0x6be0,
    arrow_down  = 0x72e0,
    arrow_right = 0x74e0,
    arrow_up    = 0x75e0,

    print_screen = 0x7ce012e0,
    pause        = 0x77f014f0e17714e1,
};

const StatusRegister = packed struct(u8) {
    output_buffer_status: u1, // 0 empty, 1 full
    input_buffer_status: u1, // 0 empty, 1 full
    system_flag: u1, // set if system passes POST
    command_or_data: u1, // 0 data in input_buffer is for device, 1 data is for controller
    _unused: u2 = 0,
    timeout_error: u1, // set if error
    parity_error: u1, // set if error
};

const Config = packed struct(u8) {
    port_0_interrupt: u1, // set if enabled
    port_1_interrupt: u1, // set if enabled
    system_flag: u1, // system passed POST
    port_0_clock: u1, // set if disabled
    port_1_clock: u1, // set if disabled
    port_0_translation: u1, // set if enabled,
    _always_0: u1 = 0,
};

const ControllerCommand = enum(u8) {
    get_config  = 0x20,
    set_config  = 0x60,
};

const Command = enum(u8) {
    set_led     = 0xed,
    echo        = 0xee,
    scancodeset = 0xf0, // Get/set scan code set, sent follow up byte
    identify    = 0xf2,
    rate_delay  = 0xf3, // Set typematic rate and delay
    enable_scanning = 0xf4,
    disable_scanning = 0xf5,
    set_default = 0xf6,

    all_typematic_autorepeat  = 0xf7, // Set all keys to typematic/autorepeat, scancode set 3 only
    all_make_release     = 0xf8, // Set all keys to make/release, scancode set 3 only
    all_make_only        = 0xf9, // Set all keys to make only, scancode set 3 only
    all_typematic_autorepeat_make_release = 0xfa, // scancode set 3 only

    set_typematic_autorepeat  = 0xfb, // Set all keys to typematic/autorepeat, scancode set 3 only
    set_make_release     = 0xfc, // Set all keys to make/release, scancode set 3 only
    set_make_only        = 0xfd, // Set all keys to make only, scancode set 3 only

    resend = 0xfe,
    reset_and_selftest = 0xff,
};

const Response = enum(u8) {
    internal_error_0   = 0x00,
    self_test_passed   = 0xaa,
    echo               = 0xee,
    ack                = 0xfa,
    self_test_failed_0 = 0xfc,
    self_test_failed_1 = 0xfd,
    resend             = 0xfe,
    internal_error_1   = 0xff,
};

fn wait_for_write() void {
    while (true) {
        if ((x86.inb(reg_cmd) & 2) == 0) {
            break;
        }
    }
}

fn wait_for_read() void {
    while (true) {
        if ((x86.inb(reg_cmd) & 1) != 0) {
            break;
        }
    }
}

pub fn init() void {
    wait_for_write();
    x86.outb(reg_cmd, @intFromEnum(ControllerCommand.get_config));
    wait_for_read();
    const config = x86.inb(reg_data);
    const mask: u8 = 1 << 6;
    x86.outb(reg_cmd, @intFromEnum(ControllerCommand.set_config));
    x86.outb(reg_data, config & ~mask);
}

pub fn handler(registers: *idt.Registers) void {
    _  = registers;
    const scancode: u64 = @intCast(x86.inb(reg_data));
    if (scancode == 0xf0) {
        _ = x86.inb(reg_data);
    }
    console.log_fmt("scancode: {x}", .{scancode});
}
