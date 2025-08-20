const std = @import("std");

pub fn get_files_from_dir(allocator: std.mem.Allocator, path: []const u8) ![][]const u8 {
    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    defer dir.close();

    var files = std.ArrayList([]const u8).init(allocator);

    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (entry.kind == .file) {
            // Copy the file name into allocator memory
            const name_copy = try allocator.dupe(u8, entry.name);
            try files.append(name_copy);
        }
    }
    return try files.toOwnedSlice();
}