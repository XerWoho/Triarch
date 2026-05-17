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
    const train_file_list = try train_file_list_alloc.toOwnedSlice();
    defer allocator.free(train_file_list);

    const OUTPUT_NODES_AMOUNT = 10;
    var layerSizes: [3]usize = .{ 28 * 28, 128, OUTPUT_NODES_AMOUNT };
    var nn = try NeuralNetwork.create(&layerSizes);

    const rand = std.crypto.random;
    for (0..10) |_| {
        var corrects: usize = 0;
        for (0..1000) |_| {
            const random = rand.intRangeAtMost(usize, 0, OUTPUT_NODES_AMOUNT - 1);
            const random_file_entry: usize = random * 6500 + random;
            const str_file_target = train_file_list[random_file_entry][0..1];
            const int_file_target = try std.fmt.parseInt(
                u8,
                str_file_target,
                10,
            );

            const flat_file = try FlatHeatmap.createFlatHeatmap(
                allocator,
                &.{ "src/nn/data/mnist_train", train_file_list[random_file_entry] },
            );
            defer flat_file.deinit();
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

            try nn.trainStep(inputs, &expected, 0.08);
        }

        std.debug.print("{d} / 1000\n", .{corrects});
    }
}
