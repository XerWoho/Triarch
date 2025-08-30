const std = @import("std");
const LayerTypes = @import("../types/layer.zig");

pub fn createInputLayer(allocator: std.mem.Allocator, amount: u32) !LayerTypes.InputLayerStruct {
	var input_layers = std.ArrayList(LayerTypes.InputStruct).init(allocator);
	for(0..amount) |_| {
		const input = LayerTypes.InputStruct{
			.activation = 0,
		};
		input_layers.append(input)  catch |err| {
			std.debug.print("{any}\n", .{err});
			@panic("Appending failed.");
		};
	}

	
	return LayerTypes.InputLayerStruct{
		.inputs = input_layers.items
	};
}