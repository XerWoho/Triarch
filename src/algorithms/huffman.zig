const std = @import("std");

const LIB_CONVERSIONS = @import("../lib/conversions.zig");
const LIB_STRING = @import("../lib/string.zig");
const LIB_CONSTANTS = @import("../lib/constants.zig");

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

const dist_fixed_symbols = struct {
    symbol: u16,
    base_distance: u32,
    extra_bits: u8,
};
pub fn dist_fixed_huffman(symbol: u8) !dist_fixed_symbols {
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
    return dist_fixed_symbols{ .symbol = symbol, .base_distance = base_distances[symbol], .extra_bits = extra_bits[symbol] };
}

const fixed_symbols = struct {
    symbol: u16,
    base_length: u32,
    extra_bits: u8,
};
fn fixed_huffman(symbol: u16) !fixed_symbols {
    const DEF_BASE_LENGTH: u8 = 3;

    return switch (symbol) {
        256 => fixed_symbols{ .symbol = symbol, .base_length = 0, .extra_bits = 0 },
        257...264 => fixed_symbols{ .symbol = symbol, .base_length = (DEF_BASE_LENGTH + LIB_CONSTANTS.BYTE_LENGTH * 0) + (symbol - 257) * 1, .extra_bits = 0 },
        265...268 => fixed_symbols{ .symbol = symbol, .base_length = (DEF_BASE_LENGTH + LIB_CONSTANTS.BYTE_LENGTH * std.math.pow(u16, LIB_CONSTANTS.BINARY_BASE, 0)) + (symbol - 265) * 2, .extra_bits = 1 },
        269...272 => fixed_symbols{ .symbol = symbol, .base_length = (DEF_BASE_LENGTH + LIB_CONSTANTS.BYTE_LENGTH * std.math.pow(u16, LIB_CONSTANTS.BINARY_BASE, 1)) + (symbol - 269) * 4, .extra_bits = 2 },
        273...276 => fixed_symbols{ .symbol = symbol, .base_length = (DEF_BASE_LENGTH + LIB_CONSTANTS.BYTE_LENGTH * std.math.pow(u16, LIB_CONSTANTS.BINARY_BASE, 2)) + (symbol - 273) * 8, .extra_bits = 3 },
        277...280 => fixed_symbols{ .symbol = symbol, .base_length = (DEF_BASE_LENGTH + LIB_CONSTANTS.BYTE_LENGTH * std.math.pow(u16, LIB_CONSTANTS.BINARY_BASE, 3)) + (symbol - 277) * 16, .extra_bits = 4 },
        281...284 => fixed_symbols{ .symbol = symbol, .base_length = (DEF_BASE_LENGTH + LIB_CONSTANTS.BYTE_LENGTH * std.math.pow(u16, LIB_CONSTANTS.BINARY_BASE, 4)) + (symbol - 281) * 16, .extra_bits = 5 },
        285 => fixed_symbols{ .symbol = symbol, .base_length = 258, .extra_bits = 0 },
        else => @panic("invalid symbol length!"),
    };
}

fn handle_btype(gpa: *std.mem.Allocator, binary: []u8, btype: u2, current_bit_position: *u32) !std.ArrayList(u8) {
    var data = std.ArrayList(u8).init(gpa.*);
    switch (btype) {
        // BTYPE 00
        0 => {
            data = try no_huffman(gpa, binary, current_bit_position);
        },
        // BTYPE 01
        1 => {
            data = try static_huffman(gpa, binary, current_bit_position);
        },
        // BTYPE 10
        2 => {
            data = try dynamic_huffman(gpa, binary, current_bit_position);
        },
        // BTYPE 11 => reserved error
        3 => @panic("invalid huffman"),
    }

    return data;
}

pub fn get_huffman_type(gpa: *std.mem.Allocator, binary: []u8) !std.ArrayList(u8) {
    var current_bit_position: u32 = 0;

    const BFINAL = binary[current_bit_position .. current_bit_position + LIB_CONSTANTS.BIT_LENGTH];
    current_bit_position += LIB_CONSTANTS.BIT_LENGTH;
    _ = BFINAL;

    const BTYPE = try LIB_STRING.reverse_string(gpa, binary[current_bit_position .. current_bit_position + LIB_CONSTANTS.BIT_LENGTH * 2]);
    current_bit_position += LIB_CONSTANTS.BIT_LENGTH * 2;
    defer BTYPE.deinit();
    const int_BTYPE = try LIB_CONVERSIONS.binary_to_int(BTYPE.items, u2);

    const handled = try handle_btype(gpa, binary, int_BTYPE, &current_bit_position);
    return handled;
}

pub fn no_huffman(gpa: *std.mem.Allocator, binary: []u8, cbp: *u32) !std.ArrayList(u8) {
    std.debug.print("NO HUFFMAN SETTING\n\n", .{});
    var current_bit_position = cbp.*;
    // skip the 5 bits to make a full byte out of the header |BFINAL (1b)|BTYPE(2b)|...(5b)|LEN|NLEN|...
    current_bit_position += 5;

    const LEN = binary[current_bit_position .. current_bit_position + LIB_CONSTANTS.BYTE_LENGTH * 2];
    current_bit_position += LIB_CONSTANTS.BYTE_LENGTH * 2;
    const negative_LEN = binary[current_bit_position .. current_bit_position + LIB_CONSTANTS.BYTE_LENGTH * 2];
    current_bit_position += LIB_CONSTANTS.BYTE_LENGTH * 2;

    const little_endian_LEN = try LIB_STRING.reverse_string(gpa, LEN);
    const little_endian_negative_LEN = try LIB_STRING.reverse_string(gpa, negative_LEN);

    const parsed_LEN = try LIB_CONVERSIONS.binary_to_int(little_endian_LEN.items, u16);
    const parsed_NLEN = try LIB_CONVERSIONS.binary_to_int(little_endian_negative_LEN.items, u16);
    if (parsed_LEN + parsed_NLEN != 65535) {
        @panic("invalid LEN and NLEN");
    }

    var BUILDER = std.ArrayList(u8).init(gpa.*);
    var enumerate: u32 = 0;
    while (enumerate < parsed_LEN) {
        const data_block = binary[current_bit_position + (enumerate * LIB_CONSTANTS.BYTE_LENGTH) .. current_bit_position + LIB_CONSTANTS.BYTE_LENGTH + (enumerate * LIB_CONSTANTS.BYTE_LENGTH)];
        const parsed_data_block: u8 = try LIB_CONVERSIONS.binary_to_int(data_block, u8);
        try BUILDER.append(parsed_data_block);
        enumerate += 1;
    }

    cbp.* = current_bit_position;
    return BUILDER;
}

pub fn static_huffman(gpa: *std.mem.Allocator, binary: []u8, cbp: *u32) !std.ArrayList(u8) {
    std.debug.print("STATIC HUFFMAN SETTING\n\n", .{});
    var current_bit_position = cbp.*;
    var BUILDER = std.ArrayList(u8).init(gpa.*);

    // fixed huffman tree
    // 0 - 143 | 8 bits   (00110000 - 10111111) (48 - 191)
    // 144 - 255 | 9 bits (110010000 - 111111111) (400 - 511)
    // 256 - 279 | 7 bits (0000000 - 0010111) (0 - 23)   POS
    // 280 - 287 | 8 bits (11000000 - 11000111) (192 - 199)   POS
    // Note: 286 and 287 have codes assigned but are RESERVED and must not appear in compressed data.
    while (current_bit_position < binary.len) {
        const first_seven = try LIB_CONVERSIONS.binary_to_int(binary[current_bit_position .. current_bit_position + 7], u16);
        check_if_seven_valid: {
            if (0 > first_seven or first_seven > 23) break :check_if_seven_valid;
            current_bit_position += 7;

            const symbol = 256 + first_seven;
            if (symbol == 256) {
                break;
            }

            const symbol_struct = try fixed_huffman(symbol);

            const extra_bits_stored = try LIB_STRING.reverse_string(gpa, binary[current_bit_position .. current_bit_position + symbol_struct.extra_bits]);
            defer extra_bits_stored.deinit();
            current_bit_position += symbol_struct.extra_bits;
            const extra_bits_int = try LIB_CONVERSIONS.binary_to_int(extra_bits_stored.items, u16);
            const total_copies = first_seven + extra_bits_int;

            const distance_symbol = try LIB_CONVERSIONS.binary_to_int(binary[current_bit_position .. current_bit_position + 5], u8);
            current_bit_position += 5;
            const set_distance_symbol = try dist_fixed_huffman(distance_symbol);

            const distance_extra_bits = try LIB_STRING.reverse_string(gpa, binary[current_bit_position .. current_bit_position + set_distance_symbol.extra_bits]);
            current_bit_position += set_distance_symbol.extra_bits;
            defer distance_extra_bits.deinit();
            const parsed_distance_extra_bits = try LIB_CONVERSIONS.binary_to_int(distance_extra_bits.items, u16);

            const u16_base: u16 = @intCast(set_distance_symbol.base_distance);
            const total_distance = u16_base + parsed_distance_extra_bits;

            std.debug.print("TOTAL COPIES {d} | TOTAL DISTANCE {d}\n", .{ total_copies, total_distance });
            continue;
        }

        const first_eight = try LIB_CONVERSIONS.binary_to_int(binary[current_bit_position .. current_bit_position + 8], u16);
        check_if_eight_valid: {
            // check if its between those values
            if (48 > first_eight or first_eight > 191) break :check_if_eight_valid;
            current_bit_position += 8;
            try BUILDER.append(@intCast(0 + first_eight - 48));
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
            const symbol_struct = try fixed_huffman(symbol);

            const extra_bits_stored = try LIB_STRING.reverse_string(gpa, binary[current_bit_position .. current_bit_position + symbol_struct.extra_bits]);
            defer extra_bits_stored.deinit();
            current_bit_position += symbol_struct.extra_bits;
            const extra_bits_int = try LIB_CONVERSIONS.binary_to_int(extra_bits_stored.items, u16);
            const total_copies = first_seven + extra_bits_int;

            const distance_symbol = try LIB_CONVERSIONS.binary_to_int(binary[current_bit_position .. current_bit_position + 5], u8);
            current_bit_position += 5;
            const set_distance_symbol = try dist_fixed_huffman(distance_symbol);

            const distance_extra_bits = try LIB_STRING.reverse_string(gpa, binary[current_bit_position .. current_bit_position + set_distance_symbol.extra_bits]);
            current_bit_position += set_distance_symbol.extra_bits;
            defer distance_extra_bits.deinit();
            const parsed_distance_extra_bits = try LIB_CONVERSIONS.binary_to_int(distance_extra_bits.items, u16);

            const u16_base: u16 = @intCast(set_distance_symbol.base_distance);
            const total_distance = u16_base + parsed_distance_extra_bits;

            std.debug.print("TOTAL COPIES {d} | TOTAL DISTANCE {d}\n", .{ total_copies, total_distance });
            continue;
        }

        const first_nine = try LIB_CONVERSIONS.binary_to_int(binary[current_bit_position .. current_bit_position + 9], u16);
        check_if_nine_valid: {
            // check if its between those values
            if (400 > first_nine or first_nine > 511) break :check_if_nine_valid;
            current_bit_position += 9;
            try BUILDER.append(@intCast(144 + first_nine - 400));
            continue;
        }
    }

    cbp.* = current_bit_position;
    return BUILDER;
}

const CODE_LENGTH_SYMBOLS = struct { symbol: u16, bits_length: u8, huffman_code: []u8 };

pub fn symbols_builder(
    gpa: *std.mem.Allocator,
    binary: []u8,
    cbp: *u32,
    CLS: std.ArrayList(CODE_LENGTH_SYMBOLS),
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
        current_bit_position += LIB_CONSTANTS.BIT_LENGTH;
        try BIT_STORER.append(BIT - LIB_CONSTANTS.INT_TO_ASCII_OFFSET);

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

                const extra_bits = binary[current_bit_position .. current_bit_position + 2];
                current_bit_position += 2;
                const rev_extra_bits = try LIB_STRING.reverse_string(gpa, extra_bits);
                defer rev_extra_bits.deinit();
                const extra_bits_parsed = try LIB_CONVERSIONS.binary_to_int(rev_extra_bits.items, u32);

                const total_repeat = 3 + extra_bits_parsed;
                for (0..total_repeat) |_| {
                    try BUILDER.append(PREVIOUS_CODE_LENGTH);
                }
            }
            if (hclen_symbol == 17) {
                const PREVIOUS_CODE_LENGTH: u8 = 0;
                const extra_bits = binary[current_bit_position .. current_bit_position + 3];
                current_bit_position += 3;
                const rev_extra_bits = try LIB_STRING.reverse_string(gpa, extra_bits);
                defer rev_extra_bits.deinit();
                const extra_bits_parsed = try LIB_CONVERSIONS.binary_to_int(rev_extra_bits.items, u32);

                const total_repeat = extra_bits_parsed + 3;
                for (0..total_repeat) |_| {
                    try BUILDER.append(PREVIOUS_CODE_LENGTH);
                }
            }
            if (hclen_symbol == 18) {
                const PREVIOUS_CODE_LENGTH: u8 = 0;
                const extra_bits = binary[current_bit_position .. current_bit_position + 7];
                current_bit_position += 7;
                const rev_extra_bits = try LIB_STRING.reverse_string(gpa, extra_bits);
                defer rev_extra_bits.deinit();
                const extra_bits_parsed = try LIB_CONVERSIONS.binary_to_int(rev_extra_bits.items, u32);

                const total_repeat = extra_bits_parsed + 11;
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

pub fn dynamic_huffman(gpa: *std.mem.Allocator, binary: []u8, cbp: *u32) !std.ArrayList(u8) {
    std.debug.print("DYNAMIC HUFFMAN SETTING\n\n", .{});

    var current_bit_position = cbp.*;
    const HLIT = binary[current_bit_position .. current_bit_position + 5];
    const revHLIT = try LIB_STRING.reverse_string(gpa, HLIT);
    defer revHLIT.deinit();
    current_bit_position += 5;
    const HDIST = binary[current_bit_position .. current_bit_position + 5];
    const revHDIST = try LIB_STRING.reverse_string(gpa, HDIST);
    defer revHDIST.deinit();
    current_bit_position += 5;
    const HCLEN = binary[current_bit_position .. current_bit_position + 4];
    const revHCLEN = try LIB_STRING.reverse_string(gpa, HCLEN);
    defer revHCLEN.deinit();
    current_bit_position += 4;

    const int_HLIT = try LIB_CONVERSIONS.binary_to_int(revHLIT.items, u16);
    const int_HDIST = try LIB_CONVERSIONS.binary_to_int(revHDIST.items, u32);
    const int_HCLEN = try LIB_CONVERSIONS.binary_to_int(revHCLEN.items, u32);

    const HCLEN_DEFAULT_SIZE = 19;
    const hclen_order: [HCLEN_DEFAULT_SIZE]u32 = [HCLEN_DEFAULT_SIZE]u32{ 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 };
    const parsed_HLIT = 257 + int_HLIT;
    // std.debug.print("(literal/length codes 2nd) HLIT: {d}\n", .{parsed_HLIT});

    const parsed_HCLEN = 4 + int_HCLEN;
    // std.debug.print("(code length code lenghts 1st) HCLEN: {d}\n", .{parsed_HCLEN});

    const parsed_HDIST = 1 + int_HDIST;
    // std.debug.print("(distance codes 3rd) HDIST: {d}\n", .{parsed_HDIST});

    const code_length = parsed_HCLEN * 3;
    _ = code_length;
    var code_lengths: [HCLEN_DEFAULT_SIZE]u8 = [_]u8{0} ** HCLEN_DEFAULT_SIZE;
    for (0..parsed_HCLEN) |i| {
        const list_code_length = binary[current_bit_position .. current_bit_position + 3];
        current_bit_position += 3;

        const rev_list_code_length = try LIB_STRING.reverse_string(gpa, list_code_length);
        defer rev_list_code_length.deinit();
        const parsed_list_code_length = try LIB_CONVERSIONS.binary_to_int(rev_list_code_length.items, u8);
        code_lengths[hclen_order[i]] = parsed_list_code_length;
    }

    var code_length_copy: [HCLEN_DEFAULT_SIZE]u8 = [_]u8{0} ** HCLEN_DEFAULT_SIZE;
    std.mem.copyBackwards(u8, &code_length_copy, &code_lengths);
    const code_creation = try handle_huffman_code_creation(gpa, &code_length_copy);

    var used_indexes = std.ArrayList(u8).init(gpa.*);
    var huffman_codes = std.ArrayList([]u8).init(gpa.*);
    var test_code = try gpa.*.alloc(u8, 1);
    test_code[0] = 2;
    for (0..code_lengths.len) |i| {
        const index_u8: u8 = @intCast(i);
        const current_code_length = code_lengths[index_u8];
        if (current_code_length == 0) {
            try huffman_codes.append(test_code);
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

    var CLS = std.ArrayList(CODE_LENGTH_SYMBOLS).init(gpa.*);
    for (0..19) |i| {
        if (code_lengths[i] == 0) continue;

        const huffman_code = huffman_codes.items[i];
        const bits_length = code_lengths[i];
        const cls: CODE_LENGTH_SYMBOLS = CODE_LENGTH_SYMBOLS{ .symbol = @intCast(i), .bits_length = bits_length, .huffman_code = huffman_code };
        try CLS.append(cls);
    }

    const HLIT_BUILDER = try symbols_builder(gpa, binary, &current_bit_position, CLS, parsed_HLIT);
    defer HLIT_BUILDER.deinit();

    const HDIST_BUILDER = try symbols_builder(gpa, binary, &current_bit_position, CLS, parsed_HDIST);
    defer HDIST_BUILDER.deinit();

    var HCH = std.ArrayList(CODE_LENGTH_SYMBOLS).init(gpa.*);
    var CODE_LENGTHS_HLIT = std.ArrayList(u8).init(gpa.*);
    for (0..HLIT_BUILDER.items.len) |i| {
        const HLIT_BIT_LENGTH = HLIT_BUILDER.items[i];
        try CODE_LENGTHS_HLIT.append(HLIT_BIT_LENGTH);
    }

    var COPY_CODE_LENGTHS_HLIT = std.ArrayList(u8).init(gpa.*);
    for (0..CODE_LENGTHS_HLIT.items.len) |i| {
        try COPY_CODE_LENGTHS_HLIT.append(CODE_LENGTHS_HLIT.items[i]);
    }

    var USED_HUFFMAN_CODES_HLIT = std.ArrayList(u16).init(gpa.*);
    const HUFFMAN_CODES_HLIT = try handle_huffman_code_creation(gpa, COPY_CODE_LENGTHS_HLIT.items);
    for (0..CODE_LENGTHS_HLIT.items.len) |i| {
        const CODE_LENGTH_HLIT = CODE_LENGTHS_HLIT.items[i];
        if (CODE_LENGTH_HLIT == 0) continue;

        for (0..HUFFMAN_CODES_HLIT.items.len) |j| {
            const j_index_u16: u16 = @intCast(j);
            const HUFFMAN_CODE_HLIT = HUFFMAN_CODES_HLIT.items[j];
            if (HUFFMAN_CODE_HLIT.len != CODE_LENGTH_HLIT) continue;
            if (std.mem.containsAtLeastScalar(u16, USED_HUFFMAN_CODES_HLIT.items, 1, j_index_u16)) continue;
            try USED_HUFFMAN_CODES_HLIT.append(j_index_u16);

            const H = CODE_LENGTH_SYMBOLS{ .bits_length = CODE_LENGTH_HLIT, .huffman_code = HUFFMAN_CODE_HLIT, .symbol = @intCast(i) };

            try HCH.append(H);
            break;
        }
    }

    var HDH = std.ArrayList(CODE_LENGTH_SYMBOLS).init(gpa.*);
    var CODE_LENGTHS_HDIST = std.ArrayList(u8).init(gpa.*);
    for (0..HDIST_BUILDER.items.len) |i| {
        const HDIST_BIT_LENGTH = HDIST_BUILDER.items[i];
        try CODE_LENGTHS_HDIST.append(HDIST_BIT_LENGTH);
    }

    var COPY_CODE_LENGTHS_HDIST = std.ArrayList(u8).init(gpa.*);
    for (0..CODE_LENGTHS_HDIST.items.len) |i| {
        try COPY_CODE_LENGTHS_HDIST.append(CODE_LENGTHS_HDIST.items[i]);
    }

    var USED_HUFFMAN_CODES_HDIST = std.ArrayList(u16).init(gpa.*);
    const HUFFMAN_CODES_HDIST = try handle_huffman_code_creation(gpa, COPY_CODE_LENGTHS_HDIST.items);
    for (0..CODE_LENGTHS_HDIST.items.len) |i| {
        const CODE_LENGTH_HDIST = CODE_LENGTHS_HDIST.items[i];
        if (CODE_LENGTH_HDIST == 0) continue;

        for (0..HUFFMAN_CODES_HDIST.items.len) |j| {
            const j_index_u16: u16 = @intCast(j);
            const HUFFMAN_CODE_HDIST = HUFFMAN_CODES_HDIST.items[j];
            if (HUFFMAN_CODE_HDIST.len != CODE_LENGTH_HDIST) continue;
            if (std.mem.containsAtLeastScalar(u16, USED_HUFFMAN_CODES_HDIST.items, 1, j_index_u16)) continue;
            try USED_HUFFMAN_CODES_HDIST.append(j_index_u16);

            const H = CODE_LENGTH_SYMBOLS{ .bits_length = CODE_LENGTH_HDIST, .huffman_code = HUFFMAN_CODE_HDIST, .symbol = @intCast(i) };

            try HDH.append(H);
            break;
        }
    }

    var BUILDER = std.ArrayList(u8).init(gpa.*);
    var HLIT_BIT_STORER = std.ArrayList(u8).init(gpa.*);

    while (current_bit_position < binary.len) {
        const BIT = binary[current_bit_position];
        current_bit_position += LIB_CONSTANTS.BIT_LENGTH;
        try HLIT_BIT_STORER.append(BIT - LIB_CONSTANTS.INT_TO_ASCII_OFFSET);

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
            try BUILDER.append(append_symbol);
            continue;
        }

        const MATCH_SYMBOL = try fixed_huffman(hlit_symbol.?);
        const EXTRA_BITS = binary[current_bit_position .. current_bit_position + MATCH_SYMBOL.extra_bits];
        const rev_HLIT_EXTRA_BITS = try LIB_STRING.reverse_string(gpa, EXTRA_BITS);
        defer rev_HLIT_EXTRA_BITS.deinit();

        current_bit_position += MATCH_SYMBOL.extra_bits;
        const PARSE_EXTRA_BITS = try LIB_CONVERSIONS.binary_to_int(rev_HLIT_EXTRA_BITS.items, u8);
        const TOTAL_COPIES = MATCH_SYMBOL.base_length + PARSE_EXTRA_BITS;
        var HDIST_BIT_STORER = std.ArrayList(u8).init(gpa.*);
        var TOTAL_DISTANCE: u16 = 0;
        while (current_bit_position < binary.len) {
            const HDIST_BIT = binary[current_bit_position];
            current_bit_position += LIB_CONSTANTS.BIT_LENGTH;
            try HDIST_BIT_STORER.append(HDIST_BIT - LIB_CONSTANTS.INT_TO_ASCII_OFFSET);

            var hdist_symbol: ?u8 = null;
            for (0..HDH.items.len) |i| {
                const H = HDH.items[i];
                if (std.mem.eql(u8, H.huffman_code, HDIST_BIT_STORER.items)) {
                    hdist_symbol = @intCast(H.symbol);
                    break;
                }
                continue;
            }
            if (hdist_symbol == null) continue;
            HDIST_BIT_STORER.clearAndFree();

            const set_hdist_symbol = try dist_fixed_huffman(hdist_symbol.?);
            const HDIST_EXTRA_BITS = binary[current_bit_position .. current_bit_position + set_hdist_symbol.extra_bits];
            current_bit_position += set_hdist_symbol.extra_bits;

            const rev_HDIST_EXTRA_BITS = try LIB_STRING.reverse_string(gpa, HDIST_EXTRA_BITS);
            defer rev_HDIST_EXTRA_BITS.deinit();
            const HDIST_PARSE_EXTRA_BITS = try LIB_CONVERSIONS.binary_to_int(rev_HDIST_EXTRA_BITS.items, u16);

            const u16_base: u16 = @intCast(set_hdist_symbol.base_distance);
            TOTAL_DISTANCE = u16_base + HDIST_PARSE_EXTRA_BITS;
            break;
        }

        // std.debug.print("match {d} {d}\n", .{ TOTAL_COPIES, TOTAL_DISTANCE });
        if (BUILDER.items.len < TOTAL_DISTANCE) {
            std.debug.print("WARNING TOTAL DISTANCE FAR EXCEEDS CURRENT LENGTH! CL: {d} | TD: {d}\n", .{ BUILDER.items.len, TOTAL_DISTANCE });
            @panic("TOTAL DISTANCE exceeds length");
        }

        for (BUILDER.items.len - TOTAL_DISTANCE..BUILDER.items.len - TOTAL_DISTANCE + TOTAL_COPIES) |i| {
            try BUILDER.append(BUILDER.items[i]);
        }
    }

    cbp.* = current_bit_position;
    return BUILDER;
}
