const std = @import("std");
const clap = @import("clap");

const LIB_CONVERSIONS = @import("lib/conversions.zig");

const A_hex_dump = @import("algorithms/hex_dump.zig");
const A_png = @import("algorithms/png.zig");
const A_huffman = @import("algorithms/huffman.zig");
const A_filter = @import("algorithms/filter.zig");
const A_grayscale = @import("algorithms/grayscale.zig");

const PNG_TYPES = @import("./types/png/png.zig");
const PIXEL_TYPES = @import("./types/pixels.zig");

const DECOMPRESS = struct {
    png: PNG_TYPES.PNGStruct,
    hex_dump: std.ArrayList(u8),
    pixels: std.ArrayList(PIXEL_TYPES.PixelStruct),
};

pub fn decompress_png(allocator: *std.mem.Allocator, path_string: []u8) !DECOMPRESS {
    const allocated_hex_dump = A_hex_dump.get_hex_dump(allocator, path_string) catch |err| {
        std.debug.print("Error: {s}\n", .{@errorName(err)});
        std.process.exit(0);
    };

    // INIT PNG
    var png = try A_png.get_png(allocator, allocated_hex_dump.items);
    // CONVERT PNG DATA
    var data = std.ArrayList(u8).init(allocator.*);
    for (0..png.IDAT.len) |i| {
        const idat = png.IDAT[i];
        try data.appendSlice(idat.data);
    }
    defer data.deinit();
    const binary_hex = try LIB_CONVERSIONS.hex_to_binary(allocator, data.items, true);
    defer binary_hex.deinit();

    // INIT HUFFMAN
    const uncompressed_data = try A_huffman.get_huffman(allocator, binary_hex.items);
    defer uncompressed_data.deinit();

    // INIT FILTER
    const pixel_data = try A_filter.get_filter(allocator, uncompressed_data, &png);
    
    return DECOMPRESS{
        .png = png,
        .hex_dump = allocated_hex_dump,
        .pixels = pixel_data,
    };
}
