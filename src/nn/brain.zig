const std = @import("std");

const NeuralNetwork = @import("./types/network.zig");
const FlatHeatmap = @import("lib/flat_heatmap.zig");
const Files = @import("lib/files.zig");
const Constants = @import("constants.zig");

fn indexOfMaxValue(inputs: []f32) usize {
    var index: usize = 0;
    var max = inputs[index];
    for (0..inputs.len) |i| {
        if (max < inputs[i]) {
            max = inputs[i];
            index = i;
        }
    }

    return index;
}

pub fn brain(allocator: std.mem.Allocator) !void {
    var train_file_list_alloc = try Files.getFilesFromDir(
        allocator,
        "src/nn/data/mnist_train/",
    );
    const train_file_list = try train_file_list_alloc.toOwnedSlice(allocator);
    defer {
        for(train_file_list) |f| {
            allocator.free(f);
        }
        allocator.free(train_file_list);
    }

    const LEARNING_RATE = 0.08;
    const MNIST_IMAGES_DISTANCE_PER_NUMBER = 6500;
    const INPUT_NODES_AMOUNT = 28 * 28;
    const HIDDEN_NODES_AMOUNT = 128;
    const OUTPUT_NODES_AMOUNT = 10;

    var layer_sizes: [3]usize = .{ INPUT_NODES_AMOUNT, HIDDEN_NODES_AMOUNT, OUTPUT_NODES_AMOUNT, };
    var nn = try NeuralNetwork.create(allocator, &layer_sizes);
    defer nn.deinit();

    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();
    var rand_implementation: std.Random.IoSource = .{ .io = io };
    var rand = rand_implementation.interface();
    for (0..10) |_| {
        var corrects: usize = 0;
        for (0..100) |_| {
            const random = rand.intRangeAtMost(usize, 0, OUTPUT_NODES_AMOUNT - 1);
            const random_file_entry: usize = random * MNIST_IMAGES_DISTANCE_PER_NUMBER + random;
            const str_file_target = train_file_list[random_file_entry][0..1];
            const int_file_target = try std.fmt.parseInt(
                u8,
                str_file_target,
                10,
            );

            var flat_file = try FlatHeatmap.createFlatHeatmap(
                allocator,
                &.{ "src/nn/data/mnist_train", train_file_list[random_file_entry] },
                28,
                28,
            );
            defer flat_file.deinit(allocator);
            const inputs = flat_file.items;

            var expected = [_]f32{0} ** OUTPUT_NODES_AMOUNT;
            expected[int_file_target] = 1;

            // feed the data with the input
            // and activations, weights
            // and biases forward
            //
            try nn.feedForward(inputs);

            const output = nn.layers[nn.layers.len - 1];
            const m = indexOfMaxValue(output.activations);
            if (m == int_file_target) corrects += 1;

            try nn.trainStep(inputs, &expected, LEARNING_RATE,);
        }

        std.debug.print("{d} / 100\n", .{corrects});
    }
}
