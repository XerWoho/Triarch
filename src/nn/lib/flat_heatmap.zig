const std = @import("std");
const decompressor = @import("../../png/decompressor.zig");
const LIB_GRAYSCALE = @import("../../png/lib/grayscale.zig");
const LIB_HEATMAP = @import("../../png/lib/heatmap.zig");

pub fn flat_heatmap(allocator: *std.mem.Allocator, entry_name: []const []const u8) !std.ArrayList(f32) {
	// Get full path
	const full_path = try std.fs.path.join(allocator.*, entry_name);
	defer allocator.free(full_path);

	// INIT PNG DECOMPRESSION + GRAYSCALE
	const decompressed = try decompressor.decompress_png(allocator, full_path);
	defer decompressed.hex_dump.deinit();
	defer decompressed.pixels.deinit();

	// INIT GRAY SCALING
	const gray_scaled = try LIB_GRAYSCALE.get_grayscale(allocator, decompressed.pixels.items, false);
	defer gray_scaled.deinit();

	// INIT HEATMAP
	const heatmap = try LIB_HEATMAP.get_heatmap(
		allocator, 
		&decompressed.png, 
		gray_scaled.items, 
		false,
		@intCast(decompressed.png.IHDR.width),
		@intCast(decompressed.png.IHDR.height)
	);
	var heatmap_flat = std.ArrayList(f32).init(allocator.*);
	for(0..heatmap.items.len) |i|{
		const h = heatmap.items[i];
		for(0..h.len) |j|{
			const p = h[j];
			try heatmap_flat.append(p);
		}
	}
	defer heatmap.deinit();

	return heatmap_flat;
}