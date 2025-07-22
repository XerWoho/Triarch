const std = @import("std");
const clap = @import("clap");

const LIB_CONVERSIONS = @import("lib/conversions.zig");

const A_hex_dump = @import("algorithms/hex_dump.zig");
const A_png = @import("algorithms/png.zig");
const A_huffman = @import("algorithms/huffman.zig");

pub fn main() !void {
    var allocator = std.heap.page_allocator;

    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Display this help and exit.
        \\-p, --path <FILE>      Input Path for the png to decompress. (required)
        \\-v, --verbose <INT>    Prints process of decompression (level 1-4).
    );

    const parsers = comptime .{
        .FILE = clap.parsers.string,
        .INT = clap.parsers.int(usize, 10),
    };

    var diag = clap.Diagnostic{};
    const res = clap.parse(clap.Help, &params, parsers, .{
        .diagnostic = &diag,
        .allocator = allocator,
    }) catch |err| {
        std.debug.print("{any}\n", .{err});
        @panic("parsing went wrong!");
    };
    defer res.deinit();

    var path_string: []u8 = &[_]u8{}; // empty fallback
    if (res.args.help != 0)
        std.debug.print("--help\n", .{});
    if (res.args.path) |p| {
        path_string = try allocator.alloc(u8, p.len);
        std.mem.copyForwards(u8, path_string, p);
    }
    if (res.args.verbose) |v|
        std.debug.print("--verbose = {d}\n", .{v});

    if (res.args.path == null) {
        std.debug.print("Path is required!", .{});
        return;
    }

    const allocated_hex_dump = try A_hex_dump.get_hex_dump(&allocator, path_string);
    defer allocated_hex_dump.deinit();

    // INIT PNG
    const png = try A_png.get_png(&allocator, allocated_hex_dump.items);

    // CONVERT PNG DATA
    const binary_hex = try LIB_CONVERSIONS.hex_to_binary(&allocator, png.IDAT.data, true);
    defer binary_hex.deinit();

    // INIT HUFFMAN
    const uncompressed_data = try A_huffman.get_huffman_type(&allocator, binary_hex.items);
    defer uncompressed_data.deinit();

    std.debug.print("UNCOMPRESSED DATA LENGTH: {d}\n", .{uncompressed_data.items.len});
    if (uncompressed_data.items.len < 50) {
        std.debug.print("UNCOMPRESSED DATA: {any}\n", .{uncompressed_data.items});
    }
}
