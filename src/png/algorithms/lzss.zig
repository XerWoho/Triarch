const std = @import("std");

const LIB_STRING = @import("../lib/string.zig");
const LIB_CONVERSIONS = @import("../lib/conversions.zig");
const CONSTANTS = @import("../constants.zig");

const TYPES_HUFFMAN = @import("../types/huffman.zig");


const dist_symbols = struct {
    symbol: u16,
    base_distance: u16,
    extra_bits: u8,
};
fn get_dist_symbol(symbol: u16) !dist_symbols {
    if (symbol >= 30) {
        return error.InvalidDistanceSymbol;
    }

    const base_distances: [30]u16 = .{
        1,     2,     3,    4,
        5,     7,     9,    13,
        17,    25,    33,   49,
        65,    97,    129,  193,
        257,   385,   513,  769,
        1025,  1537,  2049, 3073,
        4097,  6145,  8193, 12289,
        16385, 24577,
    };

    const extra_bits: [30]u8 = .{
        0,  0,  0,  0,
        1,  1,  2,  2,
        3,  3,  4,  4,
        5,  5,  6,  6,
        7,  7,  8,  8,
        9,  9,  10, 10,
        11, 11, 12, 12,
        13, 13,
    };
    return dist_symbols{ .symbol = symbol, .base_distance = base_distances[symbol], .extra_bits = extra_bits[symbol] };
}

const block_symbols = struct {
    symbol: u16,
    base_length: u32,
    extra_bits: u8,
};
fn get_block_symbol(symbol: u16) !block_symbols {
    const DEF_BASE_LENGTH: u8 = 3;

    return switch (symbol) {
        256 => block_symbols{ .symbol = symbol, .base_length = 0, .extra_bits = 0 },
        257...264 => block_symbols{
            .symbol = symbol,
            .base_length = (DEF_BASE_LENGTH + CONSTANTS.BYTE_LENGTH * 0) + (symbol - 257) * 1,
            .extra_bits = 0,
        },
        265...268 => block_symbols{
            .symbol = symbol,
            .base_length = (DEF_BASE_LENGTH + CONSTANTS.BYTE_LENGTH * std.math.pow(u16, CONSTANTS.BINARY_BASE, 0)) + (symbol - 265) * 2,
            .extra_bits = 1,
        },
        269...272 => block_symbols{
            .symbol = symbol,
            .base_length = (DEF_BASE_LENGTH + CONSTANTS.BYTE_LENGTH * std.math.pow(u16, CONSTANTS.BINARY_BASE, 1)) + (symbol - 269) * 4,
            .extra_bits = 2,
        },
        273...276 => block_symbols{
            .symbol = symbol,
            .base_length = (DEF_BASE_LENGTH + CONSTANTS.BYTE_LENGTH * std.math.pow(u16, CONSTANTS.BINARY_BASE, 2)) + (symbol - 273) * 8,
            .extra_bits = 3,
        },
        277...280 => block_symbols{
            .symbol = symbol,
            .base_length = (DEF_BASE_LENGTH + CONSTANTS.BYTE_LENGTH * std.math.pow(u16, CONSTANTS.BINARY_BASE, 3)) + (symbol - 277) * 16,
            .extra_bits = 4,
        },
        281...284 => block_symbols{
            .symbol = symbol,
            .base_length = (DEF_BASE_LENGTH + CONSTANTS.BYTE_LENGTH * std.math.pow(u16, CONSTANTS.BINARY_BASE, 4)) + (symbol - 281) * 32,
            .extra_bits = 5,
        },
        285 => block_symbols{ .symbol = symbol, .base_length = 258, .extra_bits = 0 },
        else => @panic("invalid symbol length!"),
    };
}

pub fn handle_lzss_static(
	symbol: u16,
	binary: []u8,

	complete_blocks: *std.ArrayList(u8),
	cbp: *u32,
) !void {
	var current_bit_position = cbp.*;
	const block_symbol = try get_block_symbol(symbol);
	const block_extra_bits = try LIB_CONVERSIONS.binary_to_int(binary[current_bit_position .. current_bit_position + block_symbol.extra_bits], true, u16);
	current_bit_position += block_symbol.extra_bits;
	const total_copies = block_symbol.base_length + block_extra_bits;


	const distance_symbol = try LIB_CONVERSIONS.binary_to_int(binary[current_bit_position .. current_bit_position + 5], false, u8);
	current_bit_position += 5;
	const dist_symbol = try get_dist_symbol(distance_symbol);


	const distance_extra_bits = try LIB_CONVERSIONS.binary_to_int(binary[current_bit_position .. current_bit_position + dist_symbol.extra_bits], true, u16);
	current_bit_position += dist_symbol.extra_bits;
	const total_distance = dist_symbol.base_distance + distance_extra_bits;

	if (complete_blocks.items.len < total_distance) {
		std.debug.print("WARNING TOTAL DISTANCE FAR EXCEEDS CURRENT LENGTH! CL: {d} | TD: {d}\n", .{ complete_blocks.items.len, total_distance });
		@panic("TOTAL DISTANCE exceeds length");
	}

	for (complete_blocks.items.len - total_distance..complete_blocks.items.len - total_distance + total_copies) |i| {
		try complete_blocks.append(complete_blocks.items[i]);
	}

	cbp.* = current_bit_position;
}

pub fn handle_lzss_dynamic(
	allocator: *std.mem.Allocator,
	symbol: u16,
	binary: []u8,

	HUFFMAN_DISTANCE_CODES: std.ArrayList(TYPES_HUFFMAN.CODE_LENGTH_SYMBOLS),

	complete_blocks: *std.ArrayList(u8),
	cbp: *u32,
) !void {
	var current_bit_position = cbp.*;
	const block_symbol = try get_block_symbol(symbol);

	const block_extra_bits = try LIB_CONVERSIONS.binary_to_int(binary[current_bit_position .. current_bit_position + block_symbol.extra_bits], true, u16);
	current_bit_position += block_symbol.extra_bits;
	const total_copies = block_symbol.base_length + block_extra_bits;


	var distance_symbol: ?u8 = null;
	var distance_symbol_storer = std.ArrayList(u8).init(allocator.*);
	while(current_bit_position < binary.len) {
		try distance_symbol_storer.append(binary[current_bit_position] - CONSTANTS.INT_TO_ASCII_OFFSET);
		current_bit_position += 1;
		for (0..HUFFMAN_DISTANCE_CODES.items.len) |i| {
			const H = HUFFMAN_DISTANCE_CODES.items[i];
			if (std.mem.eql(u8, H.huffman_code, distance_symbol_storer.items)) {
				distance_symbol = @intCast(H.symbol);
				break;
			}
			continue;
		}
		if (distance_symbol == null) continue;
		distance_symbol_storer.clearAndFree();
		break;
	}
	const dist_symbol = try get_dist_symbol(distance_symbol.?);

	const distance_extra_bits = try LIB_CONVERSIONS.binary_to_int(binary[current_bit_position .. current_bit_position + dist_symbol.extra_bits], true, u16);
	current_bit_position += dist_symbol.extra_bits;

	const total_distance = dist_symbol.base_distance + distance_extra_bits;
	if (complete_blocks.items.len < total_distance) {
		std.debug.print("WARNING TOTAL DISTANCE FAR EXCEEDS CURRENT LENGTH! CL: {d} | TD: {d}\n", .{ complete_blocks.items.len, total_distance });
		@panic("TOTAL DISTANCE exceeds length");
	}

	for (complete_blocks.items.len - total_distance..complete_blocks.items.len - total_distance + total_copies) |i| {
		try complete_blocks.append(complete_blocks.items[i]);
	}

	cbp.* = current_bit_position;
}