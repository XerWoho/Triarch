const std = @import("std");
const Conversions = @import("../lib/conversions.zig");
const Constants = @import("../constants.zig");
const String = @import("../lib/string.zig");

pub fn hexDump(allocator: std.mem.Allocator, bytes: []u8, little: bool) !std.ArrayList([]u8) {
    var dumped_data = try std.ArrayList([]u8).initCapacity(allocator, 20);

    var index: u32 = 0;
    while (index * Constants.HEX_BYTE_AMONUT < bytes.len) {
        var hex_dumped = try std.ArrayList(u8).initCapacity(allocator, 20);
        defer hex_dumped.deinit(allocator);
        var print_index: u8 = 0;
        for ([_]u0{0} ** Constants.HEX_SECTION_LENGTH) |_| {
            if (index * Constants.HEX_BYTE_AMONUT + print_index + Constants.HEX_PRINT_AMOUNT > bytes.len) break;
            var hex_to = try hexMultiple(allocator, bytes[index * Constants.HEX_BYTE_AMONUT + print_index .. index * Constants.HEX_BYTE_AMONUT + (Constants.HEX_PRINT_AMOUNT + print_index)], little);
            defer hex_to.deinit(allocator);

            try hex_dumped.appendSlice(allocator, hex_to.items);
            try hex_dumped.appendSlice(allocator, " ");
            print_index += Constants.HEX_PRINT_AMOUNT;
        }
        try hex_dumped.appendSlice(allocator, "\n");

        const dupe = try allocator.dupe(u8, hex_dumped.items);
        try dumped_data.append(allocator, dupe);
        index += 1;
    }

    return dumped_data;
}

pub fn hexMultiple(allocator: std.mem.Allocator, bytes: []u8, little: bool) !std.ArrayList(u8) {
    var return_string = try std.ArrayList(u8).initCapacity(allocator, 20);
    for (bytes) |byte| {
        var next_character = try Conversions.intToHex(allocator, byte);
        defer next_character.deinit(allocator);
        if (little) {
            try return_string.insertSlice(allocator, 0, next_character.items); // lil-endian
        } else {
            try return_string.appendSlice(allocator, next_character.items);
        }
    }

    return return_string;
}
