const std = @import("std");

pub fn getFilesFromDir(allocator: std.mem.Allocator, path: []const u8) !std.ArrayList([]const u8) {
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();

    const cwd = std.Io.Dir.cwd();
    const dir = try cwd.openDir(io, path, .{ .iterate = true });
    defer dir.close(io);

    var files = try std.ArrayList([]const u8).initCapacity(allocator, 20);
    errdefer {
        for (files.items) |file| {
            allocator.free(file);
        }
        files.deinit(allocator);
    }

    var it = dir.iterate();
    while (try it.next(io)) |entry| {
        if (entry.kind == .file) {
            const name_copy = try allocator.dupe(u8, entry.name);
            try files.append(allocator,name_copy);
        }
    }
    return files;
}
