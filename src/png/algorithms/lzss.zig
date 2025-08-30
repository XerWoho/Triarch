const std = @import("std");

const String = @import("../lib/string.zig");
const Conversions = @import("../lib/conversions.zig");
const Constants = @import("../constants.zig");

const HuffmanTypes = @import("../types/huffman.zig");


const DistSymbolStruct = struct {
    symbol: u16,
    base_distance: u16,
    extra_bits: u8,
};
fn getDistSymbol(symbol: u16) !DistSymbolStruct {
    if (symbol >= 30) {
        return error.InvalidDistanceSymbol;
    }

    return DistSymbolStruct{ .symbol = symbol, .base_distance = Constants.BASE_DISTANCES[symbol], .extra_bits = Constants.EXTRA_BITS[symbol] };
}

const BlockSymbolStruct = struct {
    symbol: u16,
    base_length: u32,
    extra_bits: u8,
};
fn getBlockSymbol(symbol: u16) !BlockSymbolStruct {
    return switch (symbol) {
        256 => BlockSymbolStruct{ .symbol = symbol, .base_length = 0, .extra_bits = 0 },
        257...264 => BlockSymbolStruct{
            .symbol = symbol,
            .base_length = (Constants.DEF_BASE_LENGTH + Constants.BYTE_LENGTH * 0) + (symbol - 257) * 1,
            .extra_bits = 0,
        },
        265...268 => BlockSymbolStruct{
            .symbol = symbol,
            .base_length = (Constants.DEF_BASE_LENGTH + Constants.BYTE_LENGTH * std.math.pow(u16, Constants.BINARY_BASE, 0)) + (symbol - 265) * 2,
            .extra_bits = 1,
        },
        269...272 => BlockSymbolStruct{
            .symbol = symbol,
            .base_length = (Constants.DEF_BASE_LENGTH + Constants.BYTE_LENGTH * std.math.pow(u16, Constants.BINARY_BASE, 1)) + (symbol - 269) * 4,
            .extra_bits = 2,
        },
        273...276 => BlockSymbolStruct{
            .symbol = symbol,
            .base_length = (Constants.DEF_BASE_LENGTH + Constants.BYTE_LENGTH * std.math.pow(u16, Constants.BINARY_BASE, 2)) + (symbol - 273) * 8,
            .extra_bits = 3,
        },
        277...280 => BlockSymbolStruct{
            .symbol = symbol,
            .base_length = (Constants.DEF_BASE_LENGTH + Constants.BYTE_LENGTH * std.math.pow(u16, Constants.BINARY_BASE, 3)) + (symbol - 277) * 16,
            .extra_bits = 4,
        },
        281...284 => BlockSymbolStruct{
            .symbol = symbol,
            .base_length = (Constants.DEF_BASE_LENGTH + Constants.BYTE_LENGTH * std.math.pow(u16, Constants.BINARY_BASE, 4)) + (symbol - 281) * 32,
            .extra_bits = 5,
        },
        285 => BlockSymbolStruct{ .symbol = symbol, .base_length = 258, .extra_bits = 0 },
        else => @panic("invalid symbol length!"),
    };
}

pub fn handleLzssStatic(
	symbol: u16,
	binary: []u8,

	complete_blocks: *std.ArrayList(u8),
	cbp: *u32,
) !void {
	var current_bit_position = cbp.*;
	const block_symbol = try getBlockSymbol(symbol);
	const block_extra_bits = try Conversions.binaryToInt(binary[current_bit_position .. current_bit_position + block_symbol.extra_bits], true, u16);
	current_bit_position += block_symbol.extra_bits;
	const total_copies = block_symbol.base_length + block_extra_bits;


	const distance_symbol = try Conversions.binaryToInt(binary[current_bit_position .. current_bit_position + 5], false, u8);
	current_bit_position += 5;
	const dist_symbol = try getDistSymbol(distance_symbol);


	const distance_extra_bits = try Conversions.binaryToInt(binary[current_bit_position .. current_bit_position + dist_symbol.extra_bits], true, u16);
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

pub fn handleLzssDynamic(
	allocator: std.mem.Allocator,
	symbol: u16,
	binary: []u8,
	hdist_huffman_codes: std.ArrayList(HuffmanTypes.CodeLengthSymbolsStruct),
	complete_blocks: *std.ArrayList(u8),
	cbp: *u32,
) !void {
	var current_bit_position = cbp.*;
	const block_symbol = try getBlockSymbol(symbol);

	const block_extra_bits = try Conversions.binaryToInt(binary[current_bit_position .. current_bit_position + block_symbol.extra_bits], true, u16);
	current_bit_position += block_symbol.extra_bits;
	const total_copies = block_symbol.base_length + block_extra_bits;


	var distance_symbol: ?u8 = null;
	var distance_symbol_storer = std.ArrayList(u8).init(allocator);
	while(current_bit_position < binary.len) {
		try distance_symbol_storer.append(binary[current_bit_position] - Constants.INT_TO_ASCII_OFFSET);
		current_bit_position += 1;
		for (0..hdist_huffman_codes.items.len) |i| {
			const hdist_huffman_code = hdist_huffman_codes.items[i];
			if (std.mem.eql(u8, hdist_huffman_code.huffman_code, distance_symbol_storer.items)) {
				distance_symbol = @intCast(hdist_huffman_code.symbol);
				break;
			}
			continue;
		}
		if (distance_symbol == null) continue;
		distance_symbol_storer.clearAndFree();
		break;
	}
	const dist_symbol = try getDistSymbol(distance_symbol.?);

	const distance_extra_bits = try Conversions.binaryToInt(binary[current_bit_position .. current_bit_position + dist_symbol.extra_bits], true, u16);
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