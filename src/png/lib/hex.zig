const std = @import("std");
const Conversions = @import("../lib/conversions.zig");
const Constants = @import("../constants.zig");
const String = @import("../lib/string.zig");

pub fn hexDump(allocator: std.mem.Allocator, bytes: []u8, little: bool) !std.ArrayListAligned([]u8, null) {
    var dumped_data = std.ArrayList([]u8).init(allocator);

    var index: u32 = 0;
    while (index * Constants.HEX_BYTE_AMONUT < bytes.len) {
        var hex_dumped = std.ArrayList(u8).init(allocator);
        hex_dumped.deinit();
        var print_index: u8 = 0;
        for ([_]u0{0} ** Constants.HEX_SECTION_LENGTH) |_| {
            if (index * Constants.HEX_BYTE_AMONUT + print_index + Constants.HEX_PRINT_AMOUNT > bytes.len) break;
            const hex_to = try hexMultiple(allocator, bytes[index * Constants.HEX_BYTE_AMONUT + print_index .. index * Constants.HEX_BYTE_AMONUT + (Constants.HEX_PRINT_AMOUNT + print_index)], little);
            defer hex_to.deinit();

            try hex_dumped.appendSlice(hex_to.items);
            try hex_dumped.appendSlice(" ");
            print_index += Constants.HEX_PRINT_AMOUNT;
        }
        try hex_dumped.appendSlice("\n");
        try dumped_data.append(hex_dumped.items);
        index += 1;
    }

    return dumped_data;
}

pub fn hexMultiple(allocator: std.mem.Allocator, bytes: []u8, little: bool) !std.ArrayListAligned(u8, null) {
    var return_string = std.ArrayList(u8).init(allocator);
    for (bytes) |byte| {
        const next_character = try Conversions.intToHex(allocator, byte);
        defer next_character.deinit();
        if (little) {
            try return_string.insertSlice(0, next_character.items); // lil-endian
        } else {
            try return_string.appendSlice(next_character.items);
        }
    }

    return return_string;
}
