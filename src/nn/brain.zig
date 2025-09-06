const std = @import("std");

const Network = @import("lib/network.zig");
const Calculations = @import("lib/calculations.zig");
const FlatHeatmap = @import("lib/flat_heatmap.zig");
const NumCompression = @import("lib/num_compression.zig");
const Random = @import("lib/random.zig");
const Files = @import("lib/files.zig");
const DumpWP = @import("lib/dump_wb.zig");

const Constants = @import("constants.zig");


pub fn brain(
	allocator: std.mem.Allocator,
	use_json: bool
) !void {
	var train_file_list_alloc = Files.getFilesFromDir(allocator, "src/nn/data/mnist_train/") catch |err| {
        std.debug.print("{any}\n", .{err});
        @panic("Listing training files failed.");
    };
	defer train_file_list_alloc.deinit();
	const train_file_list = try train_file_list_alloc.toOwnedSlice();
	var test_file_list_alloc = Files.getFilesFromDir(allocator, "src/nn/data/mnist_test/") catch |err| {
        std.debug.print("{any}\n", .{err});
        @panic("Listing testing files failed.");
    };
	defer test_file_list_alloc.deinit();
	const test_file_list = try test_file_list_alloc.toOwnedSlice();


	const input_size: u32 = @intCast(28 * 28);
	var hidden_layers = [_]u32{100};
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

	defer nn.input_layer.inputs.deinit();
	defer for(nn.neural_layers) |nl| {
		nl.neurons.deinit();
	};
	for(0..Constants.EPOCHS) |k|{
		var train_accuracy: f32 = 0;
		std.debug.print("EPOCH - {d}\n", .{k});
		for(0..Constants.REPETITION_CYCLE) |j| {
			for(0..Constants.BATCH_SIZE) |i| {
				const random_file_entry: usize = (i % 2) * 6500 + i;
				const flat_file = FlatHeatmap.createFlatHeatmap(
					allocator, 
					&.{ "src/nn/data/mnist_train", train_file_list[random_file_entry] }
					) catch |err| {
						std.debug.print("{any}\n", .{err});
						@panic("Getting flatmap failed.");
					};
				defer flat_file.deinit();


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
				const run_network = Calculations.runLayers(&nn, &expected_output) catch |err| {
					std.debug.print("{any}\n", .{err});
					@panic("Running layers failed.");
				};
				if(int_file_target == run_network.index) train_accuracy += 1;  // index stands for the winner number (index)
			}

			const learning_distance: f32 = @floatFromInt((Constants.REPETITION_CYCLE / (j + 1))); // how far the learning progress went
			const learning_rate = Constants.LEARNING_RATE * learning_distance;
			Calculations.setNudges(&nn, learning_rate) catch |err| {
				std.debug.print("{any}\n", .{err});
				@panic("Setting nudges failed.");
			};
		}
		std.debug.print("Training Accuracy {d}%\n", .{(train_accuracy / (Constants.REPETITION_CYCLE * Constants.BATCH_SIZE)) * 100});

		var test_accuracy: f32 = 0;
		for(0..100) |_|{
			const random_file_entry: usize = @intCast(Random.randomBetweeni32(0, @intCast(test_file_list.len - 1)));
			const new_file = FlatHeatmap.createFlatHeatmap(
				allocator, 
				&.{ "src/nn/data/mnist_test", test_file_list[random_file_entry] }
			) catch |err| {
				std.debug.print("{any}\n", .{err});
				@panic("Flat mapping failed.");
			};
			defer new_file.deinit();
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
				test_accuracy += 1;
			}
		}

		std.debug.print("Test Accuracy {d}%\n\n", .{test_accuracy});
	}

	var test_accuracy: f32 = 0;
	const test_batch = 100;
	for(0..test_batch) |_|{
		const random_file_entry: usize = @intCast(Random.randomBetweeni32(0, @intCast(test_file_list.len - 1)));
		// const random_file_entry: usize = (i % 2) * 700 + i;
		const new_file = FlatHeatmap.createFlatHeatmap(
			allocator, 
			&.{ "src/nn/data/mnist_test", test_file_list[random_file_entry] }
		) catch |err| {
			std.debug.print("{any}\n", .{err});
			@panic("Flat mapping failed.");
		};
		defer new_file.deinit();
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
			test_accuracy += 1;
		}
	}

	std.debug.print("Test Accuracy {d}%\n\n", .{test_accuracy / test_batch * 100});
	if(use_json) {
		try DumpWP.dumpWB(nn);
	}
}