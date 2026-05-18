const std = @import("std");

const Lzss = @import("./lzss.zig");
const Conversions = @import("../lib/conversions.zig");
const String = @import("../lib/string.zig");
const Constants = @import("../constants.zig");
const HuffmanTypes = @import("../types/huffman.zig");

pub fn getHuffman(allocator: std.mem.Allocator, binary: []u8) !std.ArrayList(u8) {
    var complete_blocks = try std.ArrayList(u8).initCapacity(allocator, 30);
    var current_bit_position: u32 = 0;

    var huffman = HuffmanTypes.HuffmanStruct{
        .bfinal = 0,
        .btype = 0,
        .hclen = 0,
        .hdist = 0,
        .hlit = 0,
    };

    while (true) {
        if (current_bit_position >= binary.len) break;
        const BFINAL = try Conversions.binaryToInt(binary[current_bit_position .. current_bit_position + Constants.BIT_LENGTH], true, u1);
        current_bit_position += Constants.BIT_LENGTH;
        huffman.bfinal = BFINAL;

        const BTYPE = try Conversions.binaryToInt(binary[current_bit_position .. current_bit_position + Constants.BIT_LENGTH * 2], true, u2);
        current_bit_position += Constants.BIT_LENGTH * 2;
        huffman.btype = BTYPE;

        try handleBtype(allocator, binary, &huffman, &current_bit_position, &complete_blocks);

        if (huffman.bfinal == 1) break;
    }

    return complete_blocks;
}

fn handleHuffmanCodeCreation(allocator: std.mem.Allocator, code_lengths: []u8) !std.ArrayList([]u8) {
    var stored_codes = try std.ArrayList([]u8).initCapacity(allocator, 30);
    std.mem.sort(u8, code_lengths, {}, comptime std.sort.asc(u8));

    for (0..code_lengths.len) |i| {
        const code_length = code_lengths[i];
        if (code_length == 0) continue;

        var create_code = try std.ArrayList(u8).initCapacity(allocator, 30);

        if (stored_codes.items.len > 0) {
            const last_code = stored_codes.items[stored_codes.items.len - 1];
            for (0..last_code.len) |j| {
                try create_code.append(allocator, last_code[j]);
            }
        } else {
            for (0..code_length) |_| {
                try create_code.append(allocator, 0);
            }

            if (stored_codes.items.len == 0) {
                try stored_codes.append(allocator, create_code.items);
                continue;
            }
        }
        for (0..create_code.items.len) |j| {
            const index = create_code.items.len - j - 1;
            const bit = create_code.items[index];
            const replace_bit: u8 = if (bit == 0) 1 else 0;

            _ = create_code.orderedRemove(index);
            try create_code.insert(allocator, index, replace_bit);
            if (replace_bit == 1) break;
        }
        if (stored_codes.items.len > 0) {
            const last_code = stored_codes.items[stored_codes.items.len - 1];
            for (0..code_length - last_code.len) |_| {
                try create_code.append(allocator, 0);
            }
        }

        try stored_codes.append(allocator, create_code.items);
    }

    return stored_codes;
}

fn handleBtype(allocator: std.mem.Allocator, binary: []u8, huffman: *HuffmanTypes.HuffmanStruct, current_bit_position: *u32, complete_blocks: *std.ArrayList(u8)) !void {
    switch (huffman.btype) {
        // BTYPE 00
        0 => {
            // std.debug.print("NHS\n", .{});
            try noHuffman(allocator, binary, current_bit_position, complete_blocks);
        },
        // BTYPE 01
        1 => {
            // std.debug.print("SHS\n", .{});
            try staticHuffman(allocator, binary, current_bit_position, complete_blocks);
        },
        // BTYPE 10
        2 => {
            // std.debug.print("DHS\n", .{});
            try dynamicHuffman(allocator, binary, current_bit_position, complete_blocks, huffman);
        },
        // BTYPE 11 => reserved error
        3 => @panic("invalid huffman"),
    }
}

fn noHuffman(allocator: std.mem.Allocator, binary: []u8, cbp: *u32, complete_blocks: *std.ArrayList(u8)) !void {
    var current_bit_position = cbp.*;
    // skip the 5 bits to make a full byte out of the header |BFINAL (1b)|BTYPE(2b)|...(5b)|LEN|NLEN|...
    current_bit_position += 5;

    const LEN = try Conversions.binaryToInt(binary[current_bit_position .. current_bit_position + Constants.BYTE_LENGTH * 2], true, u16);
    current_bit_position += Constants.BYTE_LENGTH * 2;
    const NLEN = try Conversions.binaryToInt(binary[current_bit_position .. current_bit_position + Constants.BYTE_LENGTH * 2], true, u16);
    current_bit_position += Constants.BYTE_LENGTH * 2;
    if (LEN + NLEN != 65535) {
        @panic("invalid LEN and NLEN");
    }

    var enumerate: u32 = 0;
    while (enumerate < LEN) {
        const data_block = binary[current_bit_position .. current_bit_position + Constants.BYTE_LENGTH];
        current_bit_position += Constants.BYTE_LENGTH;
        const parsed_data_block = try Conversions.binaryToInt(data_block, true, u8);
        try complete_blocks.append(allocator, parsed_data_block);
        enumerate += 1;
    }

    cbp.* = current_bit_position;
}

fn staticHuffman(allocator: std.mem.Allocator, binary: []u8, cbp: *u32, complete_blocks: *std.ArrayList(u8)) !void {
    var current_bit_position = cbp.*;

    // fixed huffman tree
    // 0 - 143 | 8 bits   (00110000 - 10111111) (48 - 191)
    // 144 - 255 | 9 bits (110010000 - 111111111) (400 - 511)
    // 256 - 279 | 7 bits (0000000 - 0010111) (0 - 23)   POS
    // 280 - 287 | 8 bits (11000000 - 11000111) (192 - 199)   POS
    // Note: 286 and 287 have codes assigned but are RESERVED and must not appear in compressed data.
    while (current_bit_position < binary.len) {
        const first_seven = try Conversions.binaryToInt(binary[current_bit_position .. current_bit_position + 7], false, u16);
        check_if_seven_valid: {
            if (0 > first_seven or first_seven > 23) break :check_if_seven_valid;
            current_bit_position += 7;

            const symbol = 256 + first_seven;
            if (symbol == 256) {
                break;
            }

            try Lzss.handleLzssStatic(allocator, symbol, binary, complete_blocks, &current_bit_position);
            continue;
        }

        const first_eight = try Conversions.binaryToInt(binary[current_bit_position .. current_bit_position + 8], false, u16);
        check_if_eight_valid: {
            // check if its between those values
            if (48 > first_eight or first_eight > 191) break :check_if_eight_valid;
            current_bit_position += 8;
            try complete_blocks.append(allocator, @intCast(0 + first_eight - 48));
            continue;
        }

        // 280 - 287 | 8 bits (11000000 - 11000111) (192 - 199)
        check_if_pos_valid: {
            // check if its between those values
            if (192 > first_eight or first_eight > 199) break :check_if_pos_valid;
            current_bit_position += 8;

            const symbol = 280 + (first_eight - 192);
            if (symbol > 285) {
                std.debug.print("INVALID SYMBOL", .{});
                @panic("INVALID SYMBOL");
            }

            try Lzss.handleLzssStatic(allocator, symbol, binary, complete_blocks, &current_bit_position);
            continue;
        }

        const first_nine = try Conversions.binaryToInt(binary[current_bit_position .. current_bit_position + 9], false, u16);
        check_if_nine_valid: {
            // check if its between those values
            if (400 > first_nine or first_nine > 511) break :check_if_nine_valid;
            current_bit_position += 9;
            try complete_blocks.append(allocator, @intCast(144 + first_nine - 400));
            continue;
        }
    }

    cbp.* = current_bit_position;
}

fn symbolsBuilder(
    allocator: std.mem.Allocator,
    binary: []u8,
    cbp: *u32,
    CLS: std.ArrayList(HuffmanTypes.CodeLengthSymbolsStruct),
    limit: u32,
) !std.ArrayList(u8) {
    //    0 - 15: Represent code lengths of 0 - 15
    //        16: Copy the previous code length 3 - 6 times.
    //            The next 2 bits indicate repeat length
    //                  (0 = 3, ... , 3 = 6)

    //               Example:  Codes 8, 16 (+2 bits 11),
    //                         16 (+2 bits 10) will expand to
    //                         12 code lengths of 8 (1 + 6 + 5)

    //        17: Repeat a code length of 0 for 3 - 10 times.
    //            (3 bits of length)

    //        18: Repeat a code length of 0 for 11 - 138 times
    //            (7 bits of length)

    var current_bit_position = cbp.*;
    var BUILDER = try std.ArrayList(u8).initCapacity(allocator, 30);

    var BIT_STORER = try std.ArrayList(u8).initCapacity(allocator, 30);
    defer BIT_STORER.deinit(allocator);
    while (BUILDER.items.len < limit) {
        const BIT = binary[current_bit_position];
        current_bit_position += Constants.BIT_LENGTH;
        try BIT_STORER.append(allocator, BIT - Constants.INT_TO_ASCII_OFFSET);

        var hclen_symbol: i16 = -1;
        for (0..CLS.items.len) |j| {
            const cls = CLS.items[j];
            if (std.mem.eql(u8, cls.huffman_code, BIT_STORER.items)) {
                hclen_symbol = @intCast(cls.symbol);
                break;
            }
            continue;
        }

        if (hclen_symbol != -1) {
            if (hclen_symbol < 16) {
                const CAST_HCLEN: u8 = @intCast(hclen_symbol);
                try BUILDER.append(allocator, CAST_HCLEN);
            }
            if (hclen_symbol == 16) {
                const PREVIOUS_CODE_LENGTH = BUILDER.items[BUILDER.items.len - 1];

                const extra_bits = try Conversions.binaryToInt(binary[current_bit_position .. current_bit_position + 2], true, u32);
                current_bit_position += 2;
                const total_repeat = 3 + extra_bits;
                for (0..total_repeat) |_| {
                    try BUILDER.append(allocator, PREVIOUS_CODE_LENGTH);
                }
            }
            if (hclen_symbol == 17) {
                const PREVIOUS_CODE_LENGTH: u8 = 0;
                const extra_bits = try Conversions.binaryToInt(binary[current_bit_position .. current_bit_position + 3], true, u32);
                current_bit_position += 3;
                const total_repeat = extra_bits + 3;
                for (0..total_repeat) |_| {
                    try BUILDER.append(allocator, PREVIOUS_CODE_LENGTH);
                }
            }
            if (hclen_symbol == 18) {
                const PREVIOUS_CODE_LENGTH: u8 = 0;
                const extra_bits = try Conversions.binaryToInt(binary[current_bit_position .. current_bit_position + 7], true, u32);
                current_bit_position += 7;

                const total_repeat = extra_bits + 11;
                for (0..total_repeat) |_| {
                    try BUILDER.append(allocator, PREVIOUS_CODE_LENGTH);
                }
            }
            BIT_STORER.clearAndFree(allocator);
        }
    }

    // set the bit position accordingly
    cbp.* = current_bit_position;
    return BUILDER;
}

fn huffmanBuilder(
    binary: []u8,
    huffman: *HuffmanTypes.HuffmanStruct,
    cbp: *u32,
) !void {
    var current_bit_position = cbp.*;

    const HLIT = try Conversions.binaryToInt(binary[current_bit_position .. current_bit_position + 5], true, u16);
    current_bit_position += 5;
    const HDIST = try Conversions.binaryToInt(binary[current_bit_position .. current_bit_position + 5], true, u8);
    current_bit_position += 5;
    const HCLEN = try Conversions.binaryToInt(binary[current_bit_position .. current_bit_position + 4], true, u8);
    current_bit_position += 4;

    huffman.hlit = 257 + HLIT;
    huffman.hclen = 4 + HCLEN;
    huffman.hdist = 1 + HDIST;

    cbp.* = current_bit_position;
}

fn dynamicHuffman(allocator: std.mem.Allocator, binary: []u8, cbp: *u32, complete_blocks: *std.ArrayList(u8), huffman: *HuffmanTypes.HuffmanStruct) !void {
    var current_bit_position = cbp.*;
    try huffmanBuilder(binary, huffman, &current_bit_position);


    var code_lengths = [_]u8{0} ** Constants.HCLEN_ORDER.len;
    for (0..huffman.hclen) |i| {
        const list_code_length = try Conversions.binaryToInt(binary[current_bit_position .. current_bit_position + 3], true, u8);
        current_bit_position += 3;
        code_lengths[Constants.HCLEN_ORDER[i]] = list_code_length;
    }

    var code_length_copy = [_]u8{0} ** Constants.HCLEN_ORDER.len;
    std.mem.copyBackwards(u8, &code_length_copy, &code_lengths);
    var code_creation = try handleHuffmanCodeCreation(allocator, &code_length_copy);
    defer code_creation.deinit(allocator);

    var used_indexes = try std.ArrayList(u8).initCapacity(allocator, 30);
    defer used_indexes.deinit(allocator);

    var huffman_codes = try std.ArrayList([]u8).initCapacity(allocator, 30);
    defer huffman_codes.deinit(allocator);

    for (0..code_lengths.len) |i| {
        const index_u8: u8 = @intCast(i);
        const current_code_length = code_lengths[index_u8];
        if (current_code_length == 0) {
            var test_code = [_]u8{2} ** 1;
            try huffman_codes.append(allocator, &test_code);
            continue;
        }

        for (0..code_creation.items.len) |j| {
            const j_index_u8: u8 = @intCast(j);
            if (std.mem.containsAtLeastScalar(u8, used_indexes.items, 1, j_index_u8)) continue;
            const huffman_code = code_creation.items[j];
            if (current_code_length == huffman_code.len) {
                try used_indexes.append(allocator, j_index_u8);
                try huffman_codes.append(allocator, huffman_code);
                break;
            }
        }
    }

    var CLS = try std.ArrayList(HuffmanTypes.CodeLengthSymbolsStruct).initCapacity(allocator, 30);
    defer CLS.deinit(allocator);
    for (0..19) |i| {
        if (code_lengths[i] == 0) continue;

        const huffman_code = huffman_codes.items[i];
        const bits_length = code_lengths[i];
        const cls = HuffmanTypes.CodeLengthSymbolsStruct{ .symbol = @intCast(i), .bits_length = bits_length, .huffman_code = huffman_code };
        try CLS.append(allocator, cls);
    }

    var hlit_builder = try symbolsBuilder(allocator, binary, &current_bit_position, CLS, huffman.hlit);
    defer hlit_builder.deinit(allocator);

    var hlit_huffman_codes = try buildHuffman(allocator, hlit_builder);
    defer hlit_huffman_codes.deinit(allocator);

    var hdist_builder = try symbolsBuilder(allocator, binary, &current_bit_position, CLS, huffman.hdist);
    defer hdist_builder.deinit(allocator);

    var hdist_huffman_codes = try buildHuffman(allocator, hdist_builder);
    defer hdist_huffman_codes.deinit(allocator);

    var hlit_bit_storer = try std.ArrayList(u8).initCapacity(allocator, 30);
    defer hlit_bit_storer.deinit(allocator);
    while (current_bit_position < binary.len) {
        const bit = binary[current_bit_position];
        current_bit_position += Constants.BIT_LENGTH;

        try hlit_bit_storer.append(allocator, bit - Constants.INT_TO_ASCII_OFFSET);
        var hlit_symbol: ?u16 = null;
        for (0..hlit_huffman_codes.items.len) |i| {
            const hlit_huffman_code = hlit_huffman_codes.items[i];
            if (std.mem.eql(u8, hlit_huffman_code.huffman_code, hlit_bit_storer.items)) {
                hlit_symbol = hlit_huffman_code.symbol;
                break;
            }
            continue;
        }

        if (hlit_symbol == null) continue;
        hlit_bit_storer.clearAndFree(allocator);

        if (hlit_symbol.? == 256) {
            break;
        }
        if (hlit_symbol.? < 256) {
            const append_symbol: u8 = @intCast(hlit_symbol.?);
            try complete_blocks.append(allocator, append_symbol);
            continue;
        }

        _ = try Lzss.handleLzssDynamic(allocator, hlit_symbol.?, binary, hdist_huffman_codes, complete_blocks, &current_bit_position);
    }

    cbp.* = current_bit_position;
}

fn buildHuffman(allocator: std.mem.Allocator, builder: std.ArrayList(u8)) !std.ArrayList(HuffmanTypes.CodeLengthSymbolsStruct) {
    var huffman_storer = try std.ArrayList(HuffmanTypes.CodeLengthSymbolsStruct).initCapacity(allocator, 20);
    var code_lengths_huffman = try std.ArrayList(u8).initCapacity(allocator, 20);
    defer code_lengths_huffman.deinit(allocator);

    for (builder.items) |bit_length| { // the builder contains the lengths of the bits for each code length
        try code_lengths_huffman.append(allocator, bit_length);
    }

    var copy_code_lengths_huffman = try std.ArrayList(u8).initCapacity(allocator, 30);
    defer copy_code_lengths_huffman.deinit(allocator);

    for (code_lengths_huffman.items) |code_length| {
        try copy_code_lengths_huffman.append(allocator, code_length);
    }

    var used_huffman_codes = try std.ArrayList(u16).initCapacity(allocator, 20);
    defer used_huffman_codes.deinit(allocator);

    var huffman_codes = try handleHuffmanCodeCreation(allocator, copy_code_lengths_huffman.items);
    defer huffman_codes.deinit(allocator);

    for (0..code_lengths_huffman.items.len) |i| {
        const code_length = code_lengths_huffman.items[i];
        if (code_length == 0) continue;

        for (0..huffman_codes.items.len) |j| {
            const j_index_u16: u16 = @intCast(j);
            const huffman_code = huffman_codes.items[j];
            if (huffman_code.len != code_length) continue;
            if (std.mem.containsAtLeastScalar(u16, used_huffman_codes.items, 1, j_index_u16)) continue;
            try used_huffman_codes.append(allocator, j_index_u16);

            const cls = HuffmanTypes.CodeLengthSymbolsStruct{ .bits_length = code_length, .huffman_code = huffman_code, .symbol = @intCast(i) };

            try huffman_storer.append(allocator, cls);
            break;
        }
    }

    return huffman_storer;
}
