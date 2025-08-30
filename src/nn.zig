// src/nn_main.zig
const std = @import("std");
const nn = @import("nn/brain.zig");

const clap = @import("clap");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Display this help and exit.
        \\-u, --usejson <INT>   Use (and store) pre-made weights and biases. 0 means no, 1 means yes. (0 / 1) (def: 0).
    );

    const parsers = comptime .{
        .INT = clap.parsers.int(usize, 10),
    };

    var diag = clap.Diagnostic{};
    const res = clap.parse(clap.Help, &params, parsers, .{
        .diagnostic = &diag,
        .allocator = allocator,
    }) catch |err| {
        std.debug.print("{any}\n", .{err});
        @panic("parsing went wrong!");
    };
    defer res.deinit();

    if (res.args.help != 0) {
        std.debug.print("Help for Triarch-Neural-Network.\n\n", .{});
        std.debug.print("-h, --help             Display this help and exit.\n", .{});
        std.debug.print("-u, --usejson <INT>   Use (and store) pre-made weights and biases. 0 means no, 1 means yes. (0 / 1) (def: 0)\n\n", .{});
        return;
    }

    var use_json: u8 = 0;
    if (res.args.usejson) |v|
		use_json = @intCast(v);

	nn.brain(
        allocator, 
        use_json == 1
        ) catch |err| {
        std.debug.print("{any}\n", .{err});
        @panic("Brain initializing went wrong!");
    };
}
