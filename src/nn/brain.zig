const std = @import("std");

const LIB_NETWORK = @import("lib/network.zig");
const LIB_CALCULATIONS = @import("lib/calculations.zig");
const LIB_FLAT = @import("lib/flat_heatmap.zig");
const LIB_RANDOM = @import("lib/random.zig");
const LIB_FILES = @import("lib/files.zig");


pub fn brain() !void {
	var allocator = std.heap.page_allocator;

	const train_file_list = try LIB_FILES.get_files_from_dir(allocator, "src/nn/data/mnist_train/");
	const test_file_list = try LIB_FILES.get_files_from_dir(allocator, "src/nn/data/mnist_test/");

	var hidden_layers = [_]u32{16, 16};
	var nn = try LIB_NETWORK.create_network(&allocator, @intCast(28 * 28), &hidden_layers, @intCast(10));

	const learning_rate: f32 = 0.1;
	var cost: f32 = 0;
	for(0..20) |_| {
		for(0..100) |_|{
			const random_file_entry: usize = @intCast(LIB_RANDOM.random_between_i32(0, @intCast(train_file_list.len - 1)));
			const flat_file = try LIB_FLAT.flat_heatmap(
				&allocator, 
				&.{ "src/nn/data/mnist_train", train_file_list[random_file_entry] }
				);

			const str_file_target = train_file_list[random_file_entry][0..1];
			const int_file_target = try std.fmt.parseInt(u8, str_file_target, 10);
			try LIB_NETWORK.set_input_activation(&nn, flat_file.items);
			const ran_cost = try LIB_CALCULATIONS.run_layers(&nn, int_file_target);
			cost += ran_cost;
		}
		try LIB_CALCULATIONS.set_nudges(&nn, learning_rate);
		cost = 0;
	}



	var accuracy: f32 = 0;
	for(0..1000) |_|{
		const random_file_entry: usize = @intCast(LIB_RANDOM.random_between_i32(0, @intCast(test_file_list.len - 1)));
		const new_file = try LIB_FLAT.flat_heatmap(
			&allocator, 
			&.{ "src/nn/data/mnist_test", test_file_list[random_file_entry] }
		);
		const str_file_target = test_file_list[random_file_entry][0..1];
		const int_file_target = try std.fmt.parseInt(u8, str_file_target, 10);

		try LIB_NETWORK.set_input_activation(&nn, new_file.items);
		const tn = try LIB_CALCULATIONS.test_network(&nn, int_file_target, false);
		if(tn.index == int_file_target) {
			accuracy += 1;
		}
	}

	std.debug.print("ACCURACY {d}%", .{accuracy / 10});


}