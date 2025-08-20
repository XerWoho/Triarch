const std = @import("std");

const ALGO_LZSS = @import("./lzss.zig");

const LIB_CONVERSIONS = @import("../lib/conversions.zig");
const LIB_STRING = @import("../lib/string.zig");
const CONSTANTS = @import("../constants.zig");

const TYPES_HUFFMAN = @import("../types/huffman.zig");

pub fn get_huffman(gpa: *std.mem.Allocator, binary: []u8) !std.ArrayList(u8) {
    var complete_blocks = std.ArrayList(u8).init(gpa.*);
    var current_bit_position: u32 = 0;

    var huffman = TYPES_HUFFMAN.HUFFMANStruct{
        .bfinal = 0,
        .btype = 0,
        .hclen =  0,
        .hdist =  0,
        .hlit = 0,
    };

    while (true) {
        if (current_bit_position >= binary.len) break;
        const BFINAL = try LIB_CONVERSIONS.binary_to_int(binary[current_bit_position .. current_bit_position + CONSTANTS.BIT_LENGTH], true, u1);
        current_bit_position += CONSTANTS.BIT_LENGTH;
        huffman.bfinal = BFINAL;
        
        const BTYPE = try LIB_CONVERSIONS.binary_to_int(binary[current_bit_position .. current_bit_position + CONSTANTS.BIT_LENGTH * 2], true, u2);
        current_bit_position += CONSTANTS.BIT_LENGTH * 2;
        huffman.btype = BTYPE;

        try handle_btype(gpa, binary, &huffman, &current_bit_position, &complete_blocks);

        if (huffman.bfinal == 1) break;
    }

    return complete_blocks;
}

fn handle_huffman_code_creation(gpa: *std.mem.Allocator, code_lengths: []u8) !std.ArrayList([]u8) {
    const allocator = gpa.*;
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

fn handle_btype(gpa: *std.mem.Allocator, binary: []u8, huffman: *TYPES_HUFFMAN.HUFFMANStruct, current_bit_position: *u32, complete_blocks: *std.ArrayList(u8)) !void {
    switch (huffman.btype) {
        // BTYPE 00
        0 => {
            // std.debug.print("NHS\n", .{});
            try no_huffman(binary, current_bit_position, complete_blocks);
        },
        // BTYPE 01
        1 => {
            // std.debug.print("SHS\n", .{});
            try static_huffman(binary, current_bit_position, complete_blocks);
        },
        // BTYPE 10
        2 => {
            // std.debug.print("DHS\n", .{});
            try dynamic_huffman(gpa, binary, current_bit_position, complete_blocks, huffman);
        },
        // BTYPE 11 => reserved error
        3 => @panic("invalid huffman"),
    }
}

fn no_huffman(binary: []u8, cbp: *u32, complete_blocks: *std.ArrayList(u8)) !void {
    var current_bit_position = cbp.*;
    // skip the 5 bits to make a full byte out of the header |BFINAL (1b)|BTYPE(2b)|...(5b)|LEN|NLEN|...
    current_bit_position += 5;

    const LEN = try LIB_CONVERSIONS.binary_to_int(binary[current_bit_position .. current_bit_position + CONSTANTS.BYTE_LENGTH * 2], true, u16);
    current_bit_position += CONSTANTS.BYTE_LENGTH * 2;
    const NLEN = try LIB_CONVERSIONS.binary_to_int(binary[current_bit_position .. current_bit_position + CONSTANTS.BYTE_LENGTH * 2], true, u16);
    current_bit_position += CONSTANTS.BYTE_LENGTH * 2;
    if (LEN + NLEN != 65535) {
        @panic("invalid LEN and NLEN");
    }

    var enumerate: u32 = 0;
    while (enumerate < LEN) {
        const data_block = binary[current_bit_position.. current_bit_position + CONSTANTS.BYTE_LENGTH];
        current_bit_position += CONSTANTS.BYTE_LENGTH;
        const parsed_data_block = try LIB_CONVERSIONS.binary_to_int(data_block, true, u8);
        try complete_blocks.append(parsed_data_block);
        enumerate += 1;
    }

    cbp.* = current_bit_position;
}

fn static_huffman(binary: []u8, cbp: *u32, complete_blocks: *std.ArrayList(u8)) !void {
    var current_bit_position = cbp.*;

    // fixed huffman tree
    // 0 - 143 | 8 bits   (00110000 - 10111111) (48 - 191)
    // 144 - 255 | 9 bits (110010000 - 111111111) (400 - 511)
    // 256 - 279 | 7 bits (0000000 - 0010111) (0 - 23)   POS
    // 280 - 287 | 8 bits (11000000 - 11000111) (192 - 199)   POS
    // Note: 286 and 287 have codes assigned but are RESERVED and must not appear in compressed data.
    while (current_bit_position < binary.len) {
        const first_seven = try LIB_CONVERSIONS.binary_to_int(binary[current_bit_position .. current_bit_position + 7], false, u16);
        check_if_seven_valid: {
            if (0 > first_seven or first_seven > 23) break :check_if_seven_valid;
            current_bit_position += 7;

            const symbol = 256 + first_seven;
            if (symbol == 256) {
                break;
            }


            try ALGO_LZSS.handle_lzss_static(
                symbol, 
                binary, 
                complete_blocks, 
                &current_bit_position
            );
            continue;
        }

        const first_eight = try LIB_CONVERSIONS.binary_to_int(binary[current_bit_position .. current_bit_position + 8],false, u16);
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

            try ALGO_LZSS.handle_lzss_static(
                symbol, 
                binary, 
                complete_blocks, 
                &current_bit_position
            );
            continue;
        }

        const first_nine = try LIB_CONVERSIONS.binary_to_int(binary[current_bit_position .. current_bit_position + 9], false, u16);
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

fn symbols_builder(
    gpa: *std.mem.Allocator,
    binary: []u8,
    cbp: *u32,
    CLS: std.ArrayList(TYPES_HUFFMAN.CODE_LENGTH_SYMBOLS),
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
    var BUILDER = std.ArrayList(u8).init(gpa.*);

    var BIT_STORER = std.ArrayList(u8).init(gpa.*);
    defer BIT_STORER.deinit();
    while (BUILDER.items.len < limit) {
        const BIT = binary[current_bit_position];
        current_bit_position += CONSTANTS.BIT_LENGTH;
        try BIT_STORER.append(BIT - CONSTANTS.INT_TO_ASCII_OFFSET);

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

                const extra_bits = try LIB_CONVERSIONS.binary_to_int(binary[current_bit_position .. current_bit_position + 2], true, u32);
                current_bit_position += 2;
                const total_repeat = 3 + extra_bits;
                for (0..total_repeat) |_| {
                    try BUILDER.append(PREVIOUS_CODE_LENGTH);
                }
            }
            if (hclen_symbol == 17) {
                const PREVIOUS_CODE_LENGTH: u8 = 0;
                const extra_bits = try LIB_CONVERSIONS.binary_to_int(binary[current_bit_position .. current_bit_position + 3], true, u32);
                current_bit_position += 3;
                const total_repeat = extra_bits + 3;
                for (0..total_repeat) |_| {
                    try BUILDER.append(PREVIOUS_CODE_LENGTH);
                }
            }
            if (hclen_symbol == 18) {
                const PREVIOUS_CODE_LENGTH: u8 = 0;
                const extra_bits = try LIB_CONVERSIONS.binary_to_int(binary[current_bit_position .. current_bit_position + 7], true, u32);
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

fn huffman_builder(
    binary: []u8,
    huffman: *TYPES_HUFFMAN.HUFFMANStruct,
    cbp: *u32,
) !void {
    var current_bit_position = cbp.*;

    const HLIT = try LIB_CONVERSIONS.binary_to_int(binary[current_bit_position .. current_bit_position + 5], true, u16);
    current_bit_position += 5;
    const HDIST = try LIB_CONVERSIONS.binary_to_int(binary[current_bit_position .. current_bit_position + 5], true, u8);
    current_bit_position += 5;
    const HCLEN = try LIB_CONVERSIONS.binary_to_int(binary[current_bit_position .. current_bit_position + 4], true, u8);
    current_bit_position += 4;

    huffman.hlit = 257 + HLIT;
    huffman.hclen = 4 + HCLEN;
    huffman.hdist = 1 + HDIST;

    cbp.* = current_bit_position;
}

fn dynamic_huffman(allocator: *std.mem.Allocator, binary: []u8, cbp: *u32, complete_blocks: *std.ArrayList(u8), huffman: *TYPES_HUFFMAN.HUFFMANStruct) !void {
    var current_bit_position = cbp.*;
    try huffman_builder(binary, huffman, &current_bit_position);

    var code_lengths = [_]u8{0} ** CONSTANTS.HCLEN_ORDER.len;
    for (0..huffman.hclen) |i| {
        const list_code_length = try LIB_CONVERSIONS.binary_to_int(binary[current_bit_position .. current_bit_position + 3], true, u8);
        current_bit_position += 3;
        code_lengths[CONSTANTS.HCLEN_ORDER[i]] = list_code_length;
    }

    var code_length_copy = [_]u8{0} ** CONSTANTS.HCLEN_ORDER.len;
    std.mem.copyBackwards(u8, &code_length_copy, &code_lengths);
    const code_creation = try handle_huffman_code_creation(allocator, &code_length_copy);

    var used_indexes = std.ArrayList(u8).init(allocator.*);
    var huffman_codes = std.ArrayList([]u8).init(allocator.*);

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

    var CLS = std.ArrayList(TYPES_HUFFMAN.CODE_LENGTH_SYMBOLS).init(allocator.*);
    for (0..19) |i| {
        if (code_lengths[i] == 0) continue;

        const huffman_code = huffman_codes.items[i];
        const bits_length = code_lengths[i];
        const cls = TYPES_HUFFMAN.CODE_LENGTH_SYMBOLS{ .symbol = @intCast(i), .bits_length = bits_length, .huffman_code = huffman_code };
        try CLS.append(cls);
    }

    const HLIT_BUILDER = try symbols_builder(allocator, binary, &current_bit_position, CLS, huffman.hlit);
    defer HLIT_BUILDER.deinit();

    const HDIST_BUILDER = try symbols_builder(allocator, binary, &current_bit_position, CLS, huffman.hdist);
    defer HDIST_BUILDER.deinit();

    var HCH = std.ArrayList(TYPES_HUFFMAN.CODE_LENGTH_SYMBOLS).init(allocator.*);
    var CODE_LENGTHS_HLIT = std.ArrayList(u8).init(allocator.*);
    for (0..HLIT_BUILDER.items.len) |i| {
        const HLIT_BIT_LENGTH = HLIT_BUILDER.items[i];
        try CODE_LENGTHS_HLIT.append(HLIT_BIT_LENGTH);
    }

    var COPY_CODE_LENGTHS_HLIT = std.ArrayList(u8).init(allocator.*);
    for (0..CODE_LENGTHS_HLIT.items.len) |i| {
        try COPY_CODE_LENGTHS_HLIT.append(CODE_LENGTHS_HLIT.items[i]);
    }

    var USED_HUFFMAN_CODES_HLIT = std.ArrayList(u16).init(allocator.*);
    const HUFFMAN_CODES_HLIT = try handle_huffman_code_creation(allocator, COPY_CODE_LENGTHS_HLIT.items);
    for (0..CODE_LENGTHS_HLIT.items.len) |i| {
        const CODE_LENGTH_HLIT = CODE_LENGTHS_HLIT.items[i];
        if (CODE_LENGTH_HLIT == 0) continue;

        for (0..HUFFMAN_CODES_HLIT.items.len) |j| {
            const j_index_u16: u16 = @intCast(j);
            const HUFFMAN_CODE_HLIT = HUFFMAN_CODES_HLIT.items[j];
            if (HUFFMAN_CODE_HLIT.len != CODE_LENGTH_HLIT) continue;
            if (std.mem.containsAtLeastScalar(u16, USED_HUFFMAN_CODES_HLIT.items, 1, j_index_u16)) continue;
            try USED_HUFFMAN_CODES_HLIT.append(j_index_u16);

            const H = TYPES_HUFFMAN.CODE_LENGTH_SYMBOLS{ .bits_length = CODE_LENGTH_HLIT, .huffman_code = HUFFMAN_CODE_HLIT, .symbol = @intCast(i) };

            try HCH.append(H);
            break;
        }
    }

    var HDH = std.ArrayList(TYPES_HUFFMAN.CODE_LENGTH_SYMBOLS).init(allocator.*);
    var CODE_LENGTHS_HDIST = std.ArrayList(u8).init(allocator.*);
    for (0..HDIST_BUILDER.items.len) |i| {
        const HDIST_BIT_LENGTH = HDIST_BUILDER.items[i];
        try CODE_LENGTHS_HDIST.append(HDIST_BIT_LENGTH);
    }

    var COPY_CODE_LENGTHS_HDIST = std.ArrayList(u8).init(allocator.*);
    for (0..CODE_LENGTHS_HDIST.items.len) |i| {
        try COPY_CODE_LENGTHS_HDIST.append(CODE_LENGTHS_HDIST.items[i]);
    }

    var USED_HUFFMAN_CODES_HDIST = std.ArrayList(u16).init(allocator.*);
    const HUFFMAN_CODES_HDIST = try handle_huffman_code_creation(allocator, COPY_CODE_LENGTHS_HDIST.items);
    for (0..CODE_LENGTHS_HDIST.items.len) |i| {
        const CODE_LENGTH_HDIST = CODE_LENGTHS_HDIST.items[i];
        if (CODE_LENGTH_HDIST == 0) continue;

        for (0..HUFFMAN_CODES_HDIST.items.len) |j| {
            const j_index_u16: u16 = @intCast(j);
            const HUFFMAN_CODE_HDIST = HUFFMAN_CODES_HDIST.items[j];
            if (HUFFMAN_CODE_HDIST.len != CODE_LENGTH_HDIST) continue;
            if (std.mem.containsAtLeastScalar(u16, USED_HUFFMAN_CODES_HDIST.items, 1, j_index_u16)) continue;
            try USED_HUFFMAN_CODES_HDIST.append(j_index_u16);

            const H = TYPES_HUFFMAN.CODE_LENGTH_SYMBOLS{ .bits_length = CODE_LENGTH_HDIST, .huffman_code = HUFFMAN_CODE_HDIST, .symbol = @intCast(i) };

            try HDH.append(H);
            break;
        }
    }

    var HLIT_BIT_STORER = std.ArrayList(u8).init(allocator.*);
    while (current_bit_position < binary.len) {
        const BIT = binary[current_bit_position];
        current_bit_position += CONSTANTS.BIT_LENGTH;

        try HLIT_BIT_STORER.append(BIT - CONSTANTS.INT_TO_ASCII_OFFSET);
        var hlit_symbol: ?u16 = null;
        for (0..HCH.items.len) |i| {
            const H = HCH.items[i];
            if (std.mem.eql(u8, H.huffman_code, HLIT_BIT_STORER.items)) {
                hlit_symbol = H.symbol;
                break;
            }
            continue;
        }

        if (hlit_symbol == null) continue;
        HLIT_BIT_STORER.clearAndFree();

        if (hlit_symbol.? == 256) {
            break;
        }
        if (hlit_symbol.? < 256) {
            const append_symbol: u8 = @intCast(hlit_symbol.?);
            try complete_blocks.append(append_symbol);
            continue;
        }

        _ = try ALGO_LZSS.handle_lzss_dynamic(
            allocator, 
            hlit_symbol.?, 
            binary, 
            HDH,
            complete_blocks, 
            &current_bit_position
        );
    }

    cbp.* = current_bit_position;
}
