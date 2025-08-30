const std = @import("std");
const clap = @import("clap");

const Conversions = @import("lib/conversions.zig");
const Grayscale = @import("lib/grayscale.zig");

const HexDump = @import("algorithms/hex_dump.zig");
const Png = @import("algorithms/png.zig");
const Huffman = @import("algorithms/huffman.zig");
const Filter = @import("algorithms/filter.zig");

const PngTypes = @import("./types/png/png.zig");
const PixelTypes = @import("./types/pixels.zig");

const DecompressedPngStruct = struct {
    png: PngTypes.PNGStruct,
    hex_dump: std.ArrayList(u8),
    pixels: std.ArrayList(PixelTypes.PixelStruct),
};

pub fn decompressPng(allocator: std.mem.Allocator, path_string: []u8) !DecompressedPngStruct {
    const allocated_hexDump = HexDump.getHexDump(allocator, path_string) catch |err| {
        std.debug.print("Error: {s}\n", .{@errorName(err)});
        std.process.exit(0);
    };

    // INIT PNG
    var png = Png.getPng(allocator, allocated_hexDump.items) catch |err| {
        std.debug.print("{any}\n", .{err});
        @panic("Getting PNG data failed.");
    };
    // CONVERT PNG DATA
    var data = std.ArrayList(u8).init(allocator);
    for (0..png.IDAT.len) |i| {
        const idat = png.IDAT[i];
        try data.appendSlice(idat.data);
    }
    defer data.deinit();
    const binary_hex = Conversions.hexToBinary(allocator, data.items, true) catch |err| {
        std.debug.print("{any}\n", .{err});
        @panic("Binary to hex conversion failed.");
    };
    defer binary_hex.deinit();

    // INIT HUFFMAN
    const uncompressed_data = Huffman.getHuffman(allocator, binary_hex.items) catch |err| {
        std.debug.print("{any}\n", .{err});
        @panic("Getting huffman data failed.");
    };
    defer uncompressed_data.deinit();

    // INIT FILTER
    const pixel_data = Filter.getFilter(allocator, uncompressed_data, &png) catch |err| {
        std.debug.print("{any}\n", .{err});
        @panic("Conversion of pixels via filter failed.");
    };
    
    return DecompressedPngStruct{
        .png = png,
        .hex_dump = allocated_hexDump,
        .pixels = pixel_data,
    };
}
