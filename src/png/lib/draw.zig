const std = @import("std");

const Grayscale = @import("./grayscale.zig");
const Heatmap = @import("./heatmap.zig");

const PixelTypes = @import("../../png/types/pixels.zig");
const PngTypes = @import("../../png/types/png/png.zig");

pub fn drawPng(
	allocator: std.mem.Allocator, 
	png: PngTypes.PNGStruct, 
	pixels: []PixelTypes.PixelStruct,
	invert: bool,
	square: u16
) !void {
    // INIT GRAY SCALING
	const gray_scaled = Grayscale.getGrayscale(allocator, pixels, true) catch |err| {
        std.debug.print("{any}\n", .{err});
        @panic("Grayscaling failed.");
    };
    defer gray_scaled.deinit();

    // INIT HEATMAP
    const heatmap = Heatmap.getHeatmap(
        allocator, 
        &png, 
        gray_scaled.items, 
        invert,
        square,
        square
    ) catch |err| {
        std.debug.print("{any}\n", .{err});
        @panic("Heatmapping failed.");
    };
    defer heatmap.deinit();

    std.debug.print("DRAWING NUMBER:\n", .{});
    for(0..heatmap.items.len) |i| {
        const row = heatmap.items[i];
        for(0..row.len) |j| {
            const x = row[j];
            if(x > 0.6) std.debug.print("X ", .{})
            else if(x > 0.1) std.debug.print("x ", .{})
            else if(x > 0) std.debug.print(". ", .{})
            else if(x == 0) std.debug.print("  ", .{});
        }
        std.debug.print("\n", .{});
    }
}