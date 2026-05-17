const std = @import("std");

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
    pixels: std.ArrayList(PixelTypes.PixelStruct),
};

pub fn decompressPng(allocator: std.mem.Allocator, path_string: []u8) !DecompressedPngStruct {
    var allocated_hex_dump = HexDump.getHexDump(allocator, path_string) catch |err| {
        std.debug.print("Error: {s}\n", .{@errorName(err)});
        std.process.exit(0);
    };
    defer allocated_hex_dump.deinit(allocator);

    // INIT PNG
    var png = Png.getPng(allocator, allocated_hex_dump.items) catch |err| {
        std.debug.print("{any}\n", .{err});
        @panic("Getting PNG data failed.");
    };
    defer png.IDAT.deinit(allocator);

    // CONVERT PNG DATA
    var data = try std.ArrayList(u8).initCapacity(allocator, 30);
    for (png.IDAT.items) |idat| {
        try data.appendSlice(allocator, idat.data);
    }

    defer data.deinit(allocator);
    var binary_hex = Conversions.hexToBinary(allocator, data.items, true) catch |err| {
        std.debug.print("{any}\n", .{err});
        @panic("Binary to hex conversion failed.");
    };
    defer binary_hex.deinit(allocator);

    // INIT HUFFMAN
    var uncompressed_data = Huffman.getHuffman(allocator, binary_hex.items) catch |err| {
        std.debug.print("{any}\n", .{err});
        @panic("Getting huffman data failed.");
    };
    defer uncompressed_data.deinit(allocator);

    // INIT FILTER
    const pixel_data = Filter.getFilter(allocator, uncompressed_data, &png) catch |err| {
        std.debug.print("{any}\n", .{err});
        @panic("Conversion of pixels via filter failed.");
    };

    return DecompressedPngStruct{
        .png = png,
        .pixels = pixel_data,
    };
}
