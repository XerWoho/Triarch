const std = @import("std");

const Constants = @import("../constants.zig");
const String = @import("string.zig");

// to BINARY
pub fn intToBinary(allocator: std.mem.Allocator, byte: u32) !std.ArrayListAligned(u8, null) {
    const CALCULATE_MAX_VALUE = struct {
        const MAX_VAL = struct {
            value: u32,
            pow: u16,
        };

        fn findMaxValue(sb: u32) MAX_VAL {
            var MAX: u16 = 1;
            const current_max_value = std.math.pow(u32, Constants.BINARY_BASE, MAX);
            while (current_max_value < sb) {
                MAX += 1;
            }
            MAX -= 1;
            const max_value: u32 = std.math.pow(u32, Constants.BINARY_BASE, MAX);
            return MAX_VAL{ .value = max_value, .pow = MAX };
        }
    };

    var stored_byte: u32 = byte;
    var return_string = std.ArrayList(u8).init(allocator);
    var last_max: i16 = -1;

    while (stored_byte != 0) {
        const max_value = CALCULATE_MAX_VALUE.findMaxValue(stored_byte);
        stored_byte = stored_byte - max_value.value;
        if (last_max == -1) {
            last_max = @intCast(max_value.pow);
            try return_string.appendSlice("1");
            continue;
        }

        if (last_max == max_value.pow + 1) {
            try return_string.appendSlice("1");
            continue;
        }
        for (max_value.pow..@intCast(last_max)) |_| {
            try return_string.appendSlice("0");
        }
        try return_string.appendSlice("1");
    }

    return return_string;
}

pub fn hexToBinary(allocator: std.mem.Allocator, hex: []u8, lsb: bool) !std.ArrayList(u8) {
    var return_string = std.ArrayList(u8).init(allocator);
    var index: u32 = 0;

    var byte = std.ArrayList(u8).init(allocator);
    while (index < hex.len) {
        const H = hex[index .. index + 1];

        const KEY_INDEX = std.mem.indexOf(u8, &Constants.HEX_KEYS, H);
        if (KEY_INDEX == null) {
            std.debug.print("HEX KEY NOT FOUND {s}\n", .{H});
            index += 1;
            continue;
        }

        const VALUE = Constants.HEX_VALUES[KEY_INDEX.?];
        const converted_value = try std.fmt.allocPrint(allocator, "{s}", .{VALUE});
        try byte.appendSlice(converted_value);

        if (index % 2 != 0) {
            if (lsb) {
                var reversed_converted_value = try String.reverseString(allocator, byte.items);
                defer reversed_converted_value.deinit();
                try return_string.appendSlice(reversed_converted_value.items);
            } else {
                try return_string.appendSlice(byte.items);
            }
            byte.clearAndFree();
        }
        index += 1;
    }

    return return_string;
}

// to HEX
pub fn intToHex(allocator: std.mem.Allocator, byte: u32) !std.ArrayListAligned(u8, null) {
    const DIVISOR: u8 = 16;
    var multiple: u32 = 0;
    var last_stored_quotient: u32 = byte;

    var return_string = std.ArrayList(u8).init(allocator);

    while (last_stored_quotient != 0) {
        // does division
        multiple = 0;
        while (DIVISOR * (multiple + 1) <= last_stored_quotient) {
            multiple += 1;
        }
        const remainder: u32 = last_stored_quotient - DIVISOR * multiple;
        if (remainder > 9) {
            try return_string.insertSlice(0, Constants.HEX_LETTERS[remainder - 10]);
        } else {
            const int_to_num = try std.fmt.allocPrint(allocator, "{d}", .{remainder});
            try return_string.insertSlice(0, int_to_num);
        }

        last_stored_quotient = multiple;
    }

    if (byte == 0) {
        try return_string.insertSlice(0, "0");
        try return_string.insertSlice(0, "0");
    } else if (byte <= 16) {
        if (return_string.items.len == 2) {
            return return_string;
        }
        try return_string.insertSlice(0, "0");
    }

    if (return_string.items.len == 1) {
        try return_string.insertSlice(0, "0");
    }

    return return_string;
}

pub fn binaryToHex(allocator: std.mem.Allocator, bytes: []u8) !std.ArrayListAligned(u8, null) {
    const first_conversion = try binaryToInt(bytes, false, u32);
    const second_conversion = try intToHex(allocator, first_conversion);

    return second_conversion;
}

// to INT
pub fn hexToInt(allocator: std.mem.Allocator, byte: []u8, return_type: type) !return_type {
    const hex = try std.fmt.allocPrint(allocator, "0x{s}", .{byte});
    const int: u32 = try std.fmt.parseInt(u32, hex, 0);

    const final_int: return_type = @truncate(int);
    return final_int;
}

pub fn binaryToInt(bytes: []u8, lsb: bool, return_type: type) !return_type {
    var final_int: return_type = 0;

    var b = bytes;
    var buf: [Constants.BYTE_LENGTH * 2]u8 = undefined;
    if(lsb) {
        b = try String.reverseStringNoAlloc(bytes, &buf);
    }

    var index = b.len;
    while (index > 0) {
        const pow: u16 = @intCast(b.len - index);
        const int = b[index - 1 .. index];
        const parsed_int: u16 = try std.fmt.parseInt(u16, int, 0);
        const parsed_binary = std.math.pow(u16, 2, pow);

        final_int += @intCast(parsed_int * parsed_binary);
        index -= 1;
    }

    return final_int;
}
