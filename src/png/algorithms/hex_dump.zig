const std = @import("std");

const Hex = @import("../lib/hex.zig");
const String = @import("../lib/string.zig");

fn fileExists( fn_dir:std.fs.Dir, fn_file_name:[]const u8) !bool {
    fn_dir.access(fn_file_name, .{.mode = .read_write}) catch |err| switch (err) {
        error.FileNotFound => return false,
        error.PermissionDenied => return false,
        else => {
            // (snip)
            return err;
        }
    };

    return true;
}

pub const Error = error{
    FileNotFound,
};

pub fn getHexDump(allocator: std.mem.Allocator, file_path: []u8) !std.ArrayList(u8) {
    const dir = std.fs.cwd();
    const access = try fileExists(dir, file_path);
    if(!access) {
        return Error.FileNotFound;
    }

    var file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var buf: [4096]u8 = undefined;
    var img_string = std.ArrayList(u8).init(allocator);
    defer img_string.deinit();
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try img_string.appendSlice(line);
        try img_string.appendSlice("\n");
    }

    const hexDump = try Hex.hexDump(allocator, img_string.items, false);
    defer hexDump.deinit();
    var hexDumps = std.ArrayList(u8).init(allocator);
    for (hexDump.items) |d| {
        try hexDumps.appendSlice(d);
    }

    const converted_binary = try String.removeWhitespace(allocator, hexDumps.items);
    return converted_binary;
}
