const std = @import("std");
const Decompressor = @import("../../png/decompressor.zig");
const Grayscale = @import("../../png/lib/grayscale.zig");
const Heatmap = @import("../../png/lib/heatmap.zig");

pub fn createFlatHeatmap(allocator: std.mem.Allocator, entry_name: []const []const u8) !std.ArrayList(f32) {
	// Get full path
	const full_path = try std.fs.path.join(allocator, entry_name);
	defer allocator.free(full_path);

	// INIT PNG DECOMPRESSION + GRAYSCALE
	var decompressed = try Decompressor.decompressPng(allocator, full_path);
	defer decompressed.pixels.deinit(allocator);
	defer decompressed.png.PLTE.rgb_array.deinit(allocator);

	// INIT GRAY SCALING
	var gray_scaled = try Grayscale.getGrayscale(allocator, decompressed.pixels.items, false);
	defer gray_scaled.deinit(allocator);

	// INIT HEATMAP
	var heatmap = try Heatmap.getHeatmap(
		allocator,
		&decompressed.png, 
		gray_scaled.items,
		false,
		@intCast(decompressed.png.IHDR.width),
		@intCast(decompressed.png.IHDR.height),
	);
	defer {
		for (heatmap.items) |row| {
			allocator.free(row);
		}

		heatmap.deinit(allocator);
	}

	var heatmap_flat = try std.ArrayList(f32).initCapacity(allocator, 30);
	for(0..heatmap.items.len) |i|{
		const h = heatmap.items[i];
		for(0..h.len) |j|{
			const p = h[j];
			try heatmap_flat.append(allocator, p);
		}
	}

	return heatmap_flat;
}