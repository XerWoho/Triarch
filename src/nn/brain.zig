const std = @import("std");

const Network = @import("lib/network.zig");
const Calculations = @import("lib/calculations.zig");
const FlatHeatmap = @import("lib/flat_heatmap.zig");
const NumCompression = @import("lib/num_compression.zig");
const Random = @import("lib/random.zig");
const Files = @import("lib/files.zig");
const DumpWP = @import("lib/dump_wb.zig");


pub fn brain(
	allocator: std.mem.Allocator,
	use_json: bool
) !void {
	const train_file_list = Files.getFilesFromDir(allocator, "src/nn/data/mnist_train/") catch |err| {
        std.debug.print("{any}\n", .{err});
        @panic("Listing training files failed.");
    };
	const test_file_list = Files.getFilesFromDir(allocator, "src/nn/data/mnist_test/") catch |err| {
        std.debug.print("{any}\n", .{err});
        @panic("Listing testing files failed.");
    };


	const input_size: u32 = @intCast(28 * 28);
	var hidden_layers = [_]u32{16, 16};
	const output_size: u32 = 10;
	var nn = Network.createNetwork(
		allocator, 
		input_size, 
		&hidden_layers, 
		output_size,


		use_json 
	) catch |err| {
        std.debug.print("{any}\n", .{err});
        @panic("Creating network failed.");
    };

	const REPETITION_CYCLE = 10;
	const BADGE_SIZE = 100;
	const learning_rate: f32 = 3;
	var cost: f32 = 0;
	for(0..REPETITION_CYCLE) |_| {
		for(0..BADGE_SIZE) |_| {
			const random_file_entry: usize = @intCast(Random.randomBetweeni32(@intCast(0), @intCast(train_file_list.len - 1)));
			const flat_file = FlatHeatmap.createFlatHeatmap(
				allocator, 
				&.{ "src/nn/data/mnist_train", train_file_list[random_file_entry] }
				) catch |err| {
					std.debug.print("{any}\n", .{err});
					@panic("Getting flatmap failed.");
				};


			const str_file_target = train_file_list[random_file_entry][0..1];
			const int_file_target = std.fmt.parseInt(u8, str_file_target, 10) catch |err| {
				std.debug.print("{any}\n", .{err});
				@panic("Parsing int failed.");
			};
			Network.setInputActivations(&nn, flat_file.items) catch |err| {
				std.debug.print("{any}\n", .{err});
				@panic("Setting input activation failed.");
			};

			var expected_output = [_]f32{0} ** output_size;
			expected_output[int_file_target] = 1;
			const ran_cost = Calculations.runLayers(&nn, &expected_output) catch |err| {
				std.debug.print("{any}\n", .{err});
				@panic("Running layers failed.");
			};
			cost += ran_cost;
		}
		Calculations.setNudges(&nn, learning_rate) catch |err| {
			std.debug.print("{any}\n", .{err});
			@panic("Setting nudges failed.");
		};
		// const average_cost = cost / 10;
		// std.debug.print("AVG. COST {d}\n", .{average_cost});
		cost = 0;
	}


	var accuracy: f32 = 0;
	for(0..100) |_|{
		const random_file_entry: usize = @intCast(Random.randomBetweeni32(0, @intCast(test_file_list.len - 1)));
		const new_file = FlatHeatmap.createFlatHeatmap(
			allocator, 
			&.{ "src/nn/data/mnist_test", test_file_list[random_file_entry] }
		) catch |err| {
			std.debug.print("{any}\n", .{err});
			@panic("Flat mapping failed.");
		};
		const str_file_target = test_file_list[random_file_entry][0..1];
		const int_file_target = std.fmt.parseInt(u8, str_file_target, 10) catch |err| {
			std.debug.print("{any}\n", .{err});
			@panic("Parsing int failed.");
		};
		Network.setInputActivations(&nn, new_file.items) catch |err| {
			std.debug.print("{any}\n", .{err});
			@panic("Setting inputs failed.");
		};

		var expected_output = [_]f32{0} ** output_size;
		expected_output[int_file_target] = 1;
		const test_network = Calculations.testNetwork(&nn, &expected_output, false) catch |err| {
			std.debug.print("{any}\n", .{err});
			@panic("Testing network failed.");
		};

		if(test_network.index == int_file_target) { // index == winner
			accuracy += 1;
		}
	}

	std.debug.print("ACCURACY {d}%", .{accuracy});
	if(use_json) {
		try DumpWP.dumpWB(nn);
	}
}