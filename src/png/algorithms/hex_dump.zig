const std = @import("std");

const Hex = @import("../lib/hex.zig");
const String = @import("../lib/string.zig");

fn fileExists(
    fn_dir: std.Io.Dir, 
    fn_file_name:[]const u8
) !bool {
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();

    fn_dir.access(io, fn_file_name, .{}) catch |err| switch (err) {
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
    var threaded: std.Io.Threaded = .init_single_threaded;

    const dir = std.Io.Dir.cwd();
    const access = try fileExists(dir, file_path);
    if(!access) return Error.FileNotFound;

    var file = try dir.openFile(threaded.io(), file_path, .{});
    defer file.close(threaded.io());

    var file_reader_buffer: [4096]u8 = undefined;
    var file_reader = file.reader(threaded.io(), &file_reader_buffer);

    var img_string = try std.ArrayList(u8).initCapacity(allocator, 30);
    defer img_string.deinit(allocator);

    while (try file_reader.interface.takeDelimiter('\n')) |line| {
        try img_string.appendSlice(allocator, line);
        try img_string.append(allocator, '\n');
    }

    var hex_dump = try Hex.hexDump(allocator, img_string.items, false);
    defer hex_dump.deinit(allocator);
    defer for(hex_dump.items) |dump| {
        allocator.free(dump);
    };

    var hex_dumps = try std.ArrayList(u8).initCapacity(allocator, 30);
    for (hex_dump.items) |dump| {
        try hex_dumps.appendSlice(allocator, dump);
    }
    defer hex_dumps.deinit(allocator);

    const converted_binary = try String.removeWhitespace(allocator, hex_dumps.items);
    return converted_binary;
}
