const std = @import("std");

const LIB_HEX = @import("../lib/hex.zig");
const LIB_STRING = @import("../lib/string.zig");

pub fn get_hex_dump(allocator: *std.mem.Allocator, file_path: []u8) !std.ArrayList(u8) {
    var file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var buf: [1024]u8 = undefined;
    var img_string = std.ArrayList(u8).init(allocator.*);
    defer img_string.deinit();
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try img_string.appendSlice(line);
        try img_string.appendSlice("\n");
    }

    const hex_dump = try LIB_HEX.hex_dump(allocator, img_string.items, false);
    defer hex_dump.deinit();
    var hex_dumps = std.ArrayList(u8).init(allocator.*);
    for (hex_dump.items) |d| {
        try hex_dumps.appendSlice(d);
    }

    const converted_binary = try LIB_STRING.remove_whitespace(allocator, hex_dumps.items);
    return converted_binary;
}
