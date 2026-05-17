const std = @import("std");
const clap = @import("clap");

const Decompressor = @import("./png/decompressor.zig");
const Draw = @import("./png/lib/draw.zig");

pub fn main(init: std.process.Init) !void {
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
    const res = try clap.parse(clap.Help, &params, parsers, init.minimal.args, .{
        .diagnostic = &diag,
        .allocator = allocator,
    });
    defer res.deinit();

    var invert: u8 = 0;
    var square: u16 = 10;
    var path_string: []u8 = &[_]u8{}; // empty fallback
    if (res.args.help != 0) {
        std.debug.print("Help for Triarch-Png-Decompressor.\n\n", .{});
        std.debug.print("-h, --help             Display this help and exit.\n", .{});
        std.debug.print("-p, --path <FILE>      Input Path for the png to decompress. (required)\n", .{});
        std.debug.print("-s, --square <INT>     The size of the square within png. (def: 10)\n", .{});
        std.debug.print("-v, --verbose <INT>    Prints process of decompression. (level 1-4)\n", .{});
        std.debug.print("-i, --invert <INT>     Invert the png. 0 means no, 1 means invert. (0 / 1) (def: 0)\n\n", .{});
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
	var decompressed = try Decompressor.decompressPng(allocator, path_string);
    defer decompressed.pixels.deinit(allocator);

    if(decompressed.png.IHDR.width < square or decompressed.png.IHDR.height < square) {
        std.debug.print("Square size cannot be larger than width or height!", .{});
        @panic("Invalid square num");
    }

    try Draw.drawPng(
        allocator, 
        decompressed.png, 
        decompressed.pixels.items, 
        invert == 0, 
        square
    );

	return;
}