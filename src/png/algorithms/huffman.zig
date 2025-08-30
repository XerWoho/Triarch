const std = @import("std");

const Lzss = @import("./lzss.zig");

const Conversions = @import("../lib/conversions.zig");
const String = @import("../lib/string.zig");
const Constants = @import("../constants.zig");

const HuffmanTypes = @import("../types/huffman.zig");

pub fn getHuffman(allocator: std.mem.Allocator, binary: []u8) !std.ArrayList(u8) {
    var complete_blocks = std.ArrayList(u8).init(allocator);
    var current_bit_position: u32 = 0;

    var huffman = HuffmanTypes.HuffmanStruct{
        .bfinal = 0,
        .btype = 0,
        .hclen =  0,
        .hdist =  0,
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
    var stored_codes = std.ArrayList([]u8).init(allocator);
    std.mem.sort(u8, code_lengths, {}, comptime std.sort.asc(u8));

    for (0..code_lengths.len) |i| {
        const code_length = code_lengths[i];
        if (code_length == 0) continue;

        var create_code = std.ArrayList(u8).init(allocator);
        if (stored_codes.items.len > 0) {
            const last_code = stored_codes.items[stored_codes.items.len - 1];
            for (0..last_code.len) |j| {
                try create_code.append(last_code[j]);
            }
        } else {
            for (0..code_length) |_| {
                try create_code.append(0);
            }

            if (stored_codes.items.len == 0) {
                try stored_codes.append(create_code.items);
                continue;
            }
        }
        for (0..create_code.items.len) |j| {
            const index = create_code.items.len - j - 1;
            const bit = create_code.items[index];
            const replace_bit: u8 = if (bit == 0) 1 else 0;

            _ = create_code.orderedRemove(index);
            try create_code.insert(index, replace_bit);
            if (replace_bit == 1) break;
        }

        if (stored_codes.items.len > 0) {
            const last_code = stored_codes.items[stored_codes.items.len - 1];
            for (0..code_length - last_code.len) |_| {
                try create_code.append(0);
            }
        }

        try stored_codes.append(create_code.items);
    }

    return stored_codes;
}

fn handleBtype(allocator: std.mem.Allocator, binary: []u8, huffman: *HuffmanTypes.HuffmanStruct, current_bit_position: *u32, complete_blocks: *std.ArrayList(u8)) !void {
    switch (huffman.btype) {
        // BTYPE 00
        0 => {
            // std.debug.print("NHS\n", .{});
            try noHuffman(binary, current_bit_position, complete_blocks);
        },
        // BTYPE 01
        1 => {
            // std.debug.print("SHS\n", .{});
            try staticHuffman(binary, current_bit_position, complete_blocks);
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

fn noHuffman(binary: []u8, cbp: *u32, complete_blocks: *std.ArrayList(u8)) !void {
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
        const data_block = binary[current_bit_position.. current_bit_position + Constants.BYTE_LENGTH];
        current_bit_position += Constants.BYTE_LENGTH;
        const parsed_data_block = try Conversions.binaryToInt(data_block, true, u8);
        try complete_blocks.append(parsed_data_block);
        enumerate += 1;
    }

    cbp.* = current_bit_position;
}

fn staticHuffman(binary: []u8, cbp: *u32, complete_blocks: *std.ArrayList(u8)) !void {
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


            try Lzss.handleLzssStatic(
                symbol, 
                binary, 
                complete_blocks, 
                &current_bit_position
            );
            continue;
        }

        const first_eight = try Conversions.binaryToInt(binary[current_bit_position .. current_bit_position + 8],false, u16);
        check_if_eight_valid: {
            // check if its between those values
            if (48 > first_eight or first_eight > 191) break :check_if_eight_valid;
            current_bit_position += 8;
            try complete_blocks.append(@intCast(0 + first_eight - 48));
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

            try Lzss.handleLzssStatic(
                symbol, 
                binary, 
                complete_blocks, 
                &current_bit_position
            );
            continue;
        }

        const first_nine = try Conversions.binaryToInt(binary[current_bit_position .. current_bit_position + 9], false, u16);
        check_if_nine_valid: {
            // check if its between those values
            if (400 > first_nine or first_nine > 511) break :check_if_nine_valid;
            current_bit_position += 9;
            try complete_blocks.append(@intCast(144 + first_nine - 400));
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
    var BUILDER = std.ArrayList(u8).init(allocator);

    var BIT_STORER = std.ArrayList(u8).init(allocator);
    defer BIT_STORER.deinit();
    while (BUILDER.items.len < limit) {
        const BIT = binary[current_bit_position];
        current_bit_position += Constants.BIT_LENGTH;
        try BIT_STORER.append(BIT - Constants.INT_TO_ASCII_OFFSET);

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
                try BUILDER.append(CAST_HCLEN);
            }
            if (hclen_symbol == 16) {
                const PREVIOUS_CODE_LENGTH = BUILDER.items[BUILDER.items.len - 1];

                const extra_bits = try Conversions.binaryToInt(binary[current_bit_position .. current_bit_position + 2], true, u32);
                current_bit_position += 2;
                const total_repeat = 3 + extra_bits;
                for (0..total_repeat) |_| {
                    try BUILDER.append(PREVIOUS_CODE_LENGTH);
                }
            }
            if (hclen_symbol == 17) {
                const PREVIOUS_CODE_LENGTH: u8 = 0;
                const extra_bits = try Conversions.binaryToInt(binary[current_bit_position .. current_bit_position + 3], true, u32);
                current_bit_position += 3;
                const total_repeat = extra_bits + 3;
                for (0..total_repeat) |_| {
                    try BUILDER.append(PREVIOUS_CODE_LENGTH);
                }
            }
            if (hclen_symbol == 18) {
                const PREVIOUS_CODE_LENGTH: u8 = 0;
                const extra_bits = try Conversions.binaryToInt(binary[current_bit_position .. current_bit_position + 7], true, u32);
                current_bit_position += 7;

                const total_repeat = extra_bits + 11;
                for (0..total_repeat) |_| {
                    try BUILDER.append(PREVIOUS_CODE_LENGTH);
                }
            }
            BIT_STORER.clearAndFree();
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
    const code_creation = try handleHuffmanCodeCreation(allocator, &code_length_copy);

    var used_indexes = std.ArrayList(u8).init(allocator);
    var huffman_codes = std.ArrayList([]u8).init(allocator);

    for (0..code_lengths.len) |i| {
        const index_u8: u8 = @intCast(i);
        const current_code_length = code_lengths[index_u8];
        if (current_code_length == 0) {
            var test_code = [_]u8{2} ** 1;
            try huffman_codes.append(&test_code);
            continue;
        }

        for (0..code_creation.items.len) |j| {
            const j_index_u8: u8 = @intCast(j);
            if (std.mem.containsAtLeastScalar(u8, used_indexes.items, 1, j_index_u8)) continue;
            const huffman_code = code_creation.items[j];
            if (current_code_length == huffman_code.len) {
                try used_indexes.append(j_index_u8);
                try huffman_codes.append(huffman_code);
                break;
            }
        }
    }

    var CLS = std.ArrayList(HuffmanTypes.CodeLengthSymbolsStruct).init(allocator);
    for (0..19) |i| {
        if (code_lengths[i] == 0) continue;

        const huffman_code = huffman_codes.items[i];
        const bits_length = code_lengths[i];
        const cls = HuffmanTypes.CodeLengthSymbolsStruct{ .symbol = @intCast(i), .bits_length = bits_length, .huffman_code = huffman_code };
        try CLS.append(cls);
    }

    const hlit_builder = try symbolsBuilder(allocator, binary, &current_bit_position, CLS, huffman.hlit);
    defer hlit_builder.deinit();
    const hlit_huffman_codes = try buildHuffman(hlit_builder);


    const hdist_builder = try symbolsBuilder(allocator, binary, &current_bit_position, CLS, huffman.hdist);
    defer hdist_builder.deinit();
    const hdist_huffman_codes = try buildHuffman(hdist_builder);

    var hlit_bit_storer = std.ArrayList(u8).init(allocator);
    while (current_bit_position < binary.len) {
        const bit = binary[current_bit_position];
        current_bit_position += Constants.BIT_LENGTH;

        try hlit_bit_storer.append(bit - Constants.INT_TO_ASCII_OFFSET);
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
        hlit_bit_storer.clearAndFree();

        if (hlit_symbol.? == 256) {
            break;
        }
        if (hlit_symbol.? < 256) {
            const append_symbol: u8 = @intCast(hlit_symbol.?);
            try complete_blocks.append(append_symbol);
            continue;
        }

        _ = try Lzss.handleLzssDynamic(
            allocator, 
            hlit_symbol.?, 
            binary, 
            hdist_huffman_codes,
            complete_blocks, 
            &current_bit_position
        );
    }

    cbp.* = current_bit_position;
}


fn buildHuffman(builder: std.ArrayList(u8)) !std.ArrayList(HuffmanTypes.CodeLengthSymbolsStruct) {
    const allocator = std.heap.page_allocator;

    var huffman_storer = std.ArrayList(HuffmanTypes.CodeLengthSymbolsStruct).init(allocator);
    var code_lengths_huffman = std.ArrayList(u8).init(allocator);
    for (0..builder.items.len) |i| {
        const bit_length = builder.items[i];
        try code_lengths_huffman.append(bit_length);
    }

    var copy_code_lengths_huffman = std.ArrayList(u8).init(allocator);
    for (0..code_lengths_huffman.items.len) |i| {
        try copy_code_lengths_huffman.append(code_lengths_huffman.items[i]);
    }

    var used_huffman_codes = std.ArrayList(u16).init(allocator);
    const huffman_codes = try handleHuffmanCodeCreation(allocator, copy_code_lengths_huffman.items);
    for (0..code_lengths_huffman.items.len) |i| {
        const code_length = code_lengths_huffman.items[i];
        if (code_length == 0) continue;

        for (0..huffman_codes.items.len) |j| {
            const j_index_u16: u16 = @intCast(j);
            const huffman_code = huffman_codes.items[j];
            if (huffman_code.len != code_length) continue;
            if (std.mem.containsAtLeastScalar(u16, used_huffman_codes.items, 1, j_index_u16)) continue;
            try used_huffman_codes.append(j_index_u16);

            const cls = HuffmanTypes.CodeLengthSymbolsStruct{ .bits_length = code_length, .huffman_code = huffman_code, .symbol = @intCast(i) };

            try huffman_storer.append(cls);
            break;
        }
    }

    return huffman_storer;
}