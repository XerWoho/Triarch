const std = @import("std");
const LIB_CONVERSIONS = @import("lib/conversions.zig");

const A_hex_dump = @import("algorithms/hex_dump.zig");
const A_png = @import("algorithms/png.zig");
const A_huffman = @import("algorithms/huffman.zig");

pub fn main() !void {
    var allocator = std.heap.page_allocator;

    const path: []u8 = try std.fmt.allocPrint(allocator, "tests/test.png", .{});
    const allocated_hex_dump = try A_hex_dump.get_hex_dump(&allocator, path);
    defer allocated_hex_dump.deinit();

    // INIT PNG DATA
    const png = try A_png.get_png(&allocator, allocated_hex_dump.items);

    // INIT PNG DATA
    const binary_hex = try LIB_CONVERSIONS.hex_to_binary(&allocator, png.IDAT.data, true);
    defer binary_hex.deinit();

    // INIT HUFFMAN DATA
    try A_huffman.get_huffman_type(&allocator, binary_hex.items);
}
