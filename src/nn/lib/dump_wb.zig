const std = @import("std");
const NetworkTypes = @import("../types/network.zig");


pub fn dumpWB(nn: NetworkTypes.NetworkStruct) !void {
	const allocator = std.heap.page_allocator;
	var data_storer = std.ArrayList([]NetworkTypes.DumpNeuronDataStruct).init(allocator);

	for(0.., nn.neural_layers) |layer_index, layer| {
		var data_layer = std.ArrayList(NetworkTypes.DumpNeuronDataStruct).init(allocator);
		for(0.., layer.neurons) |neuron_index, neuron| {
			const data = NetworkTypes.DumpNeuronDataStruct{
				.bias = neuron.bias,
				.weights = neuron.connection_weights,
				.layer_index = @intCast(layer_index),
				.neuron_index = @intCast(neuron_index)
			};

			try data_layer.append(data);
		}
		try data_storer.append(data_layer.items);
	}

    var string = std.ArrayList(u8).init(allocator);
    try std.json.stringify(data_storer.items, .{}, string.writer());


    var file = try std.fs.cwd().createFile("output.json", .{});
	defer file.close();
	try file.writeAll(string.items);
	return;
}