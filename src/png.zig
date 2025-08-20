const std = @import("std");
const clap = @import("clap");
const decompress = @import("./png/decompressor.zig");

const LIB_GRAYSCALE = @import("./png/lib/grayscale.zig");
const LIB_HEATMAP = @import("./png/lib/heatmap.zig");

pub fn main() !void {
	var allocator = std.heap.page_allocator;

    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Display this help and exit.
        \\-p, --path <FILE>      Input Path for the png to decompress. (required)
        \\-s, --square <INT>     The size of the square within png. (def: 10)
        \\-v, --verbose <INT>    Prints process of decompression (level 1-4).
        \\-i, --invert <INT>    Invert the png. 0 means no, 1 means invert. (0 / 1) (def: 0).
    );

    const parsers = comptime .{
        .FILE = clap.parsers.string,
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

    var invert: u8 = 0;
    var square: u16 = 10;
    var path_string: []u8 = &[_]u8{}; // empty fallback
    if (res.args.help != 0) {
        std.debug.print("Help of Triarch.\n\n", .{});
        std.debug.print("-h, --help             Display this help and exit.\n", .{});
        std.debug.print("-p, --path <FILE>      Input Path for the png to decompress. (required)\n", .{});
        std.debug.print("-s, --square <INT>     The size of the square within png. (def: 10)\n", .{});
        std.debug.print("-v, --verbose <INT>    Prints process of decompression. (level 1-4)\n", .{});
        std.debug.print("-i, --invert <INT>    Invert the png. 0 means no, 1 means invert. (0 / 1) (def: 0)\n\n", .{});
        return;
    }
    if (res.args.path) |p| {
        path_string = try allocator.alloc(u8, p.len);
        std.mem.copyForwards(u8, path_string, p);
    }
    if (res.args.verbose) |v|
        std.debug.print("--verbose = {d}\n", .{v});
    
	if (res.args.square) |v|
		square = @intCast(v);
	
    if (res.args.invert) |v|
		invert = @intCast(v);

    if (res.args.path == null) {
        std.debug.print("Path is required!", .{});
        return;
    }


    // INIT PNG DECOMPRESSION + GRAYSCALE
	const decompressed = try decompress.decompress_png(&allocator, path_string);
    defer decompressed.hex_dump.deinit();
    defer decompressed.pixels.deinit();

    // INIT GRAY SCALING
	const gray_scaled = try LIB_GRAYSCALE.get_grayscale(&allocator, decompressed.pixels.items, true);
    defer gray_scaled.deinit();

    // INIT HEATMAP
    const heatmap = try LIB_HEATMAP.get_heatmap(
        &allocator, 
        &decompressed.png, 
        gray_scaled.items, 
        invert == 0,
        square,
        square
    );
    defer heatmap.deinit();

    std.debug.print("DRAWING NUMBER:\n", .{});
    for(0..heatmap.items.len) |i| {
        const row = heatmap.items[i];
        for(0..row.len) |j| {
            const x = row[j];
            if(x > 0.6) std.debug.print("X ", .{})
            else if(x > 0.1) std.debug.print("x ", .{})
            else if(x > 0) std.debug.print(". ", .{})
            else if(x == 0) std.debug.print("  ", .{});
        }
        std.debug.print("\n", .{});
    }

	return;
}