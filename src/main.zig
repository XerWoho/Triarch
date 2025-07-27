const std = @import("std");
const clap = @import("clap");

const LIB_CONVERSIONS = @import("lib/conversions.zig");

const A_hex_dump = @import("algorithms/hex_dump.zig");
const A_png = @import("algorithms/png.zig");
const A_huffman = @import("algorithms/huffman.zig");
const A_filter = @import("algorithms/filter.zig");
const A_grayscale = @import("algorithms/grayscale.zig");
const A_square_average = @import("algorithms/square_average.zig");

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
    var png = try A_png.get_png(&allocator, allocated_hex_dump.items);
    // std.debug.print("WIDTH: {d}\n", .{png.IHDR.width});
    // std.debug.print("HEIGHT: {d}\n", .{png.IHDR.height});
    // std.debug.print("COLOR TYPE: {d}\n", .{png.IHDR.color_type});
    // std.debug.print("BITS PER PIXEL: {d}\n", .{png.IHDR.bits_per_pixel});
    // std.debug.print("IDAT: {d}\n", .{png.IDAT.size});

    // CONVERT PNG DATA
    var data = std.ArrayList(u8).init(allocator);
    for (0..png.IDAT.len) |i| {
        const idat = png.IDAT[i];
        try data.appendSlice(idat.data);
    }
    defer data.deinit();
    const binary_hex = try LIB_CONVERSIONS.hex_to_binary(&allocator, data.items, true);
    defer binary_hex.deinit();

    // INIT HUFFMAN
    const uncompressed_data = try A_huffman.get_huffman(&allocator, binary_hex.items);
    defer uncompressed_data.deinit();

    std.debug.print("UNCOMPRESSED DATA LENGTH: {d}\n", .{uncompressed_data.items.len});

    // INIT FILTER
    var pixel_data = try A_filter.get_filter(&allocator, uncompressed_data, &png);
    defer pixel_data.deinit();

    // INIT GRAYSCALE
    const grayscale_data = try A_grayscale.get_grayscale(&allocator, pixel_data.items);
    defer grayscale_data.deinit();

    // INIT SQUARE AVERAGE
    const square_average = try A_square_average.get_square_average(&allocator, &png, grayscale_data.items, 40);
    defer square_average.deinit();

    for (0..square_average.items.len) |i| {
        std.debug.print("{any}\n", .{square_average.items[i]});
    }
}
