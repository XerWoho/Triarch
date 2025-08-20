const std = @import("std");
const PNG_TYPES = @import("../types/png/png.zig");
const CRITICAL_CHUNK_TYPES = @import("../types/png/chunks/critial.zig");

const LIB_HEX = @import("../lib/hex.zig");
const LIB_STRING = @import("../lib/string.zig");
const LIB_CONVERSIONS = @import("../lib/conversions.zig");
const CONSTANTS = @import("../constants.zig");

pub fn get_png(allocator: *std.mem.Allocator, binary: []u8) !PNG_TYPES.PNGStruct {
    var current_bit_position: u32 = 0;
    var png: PNG_TYPES.PNGStruct = undefined;

    const png_sig_slice = binary[current_bit_position .. current_bit_position + CONSTANTS.BYTE_LENGTH * 2];
    current_bit_position += CONSTANTS.BYTE_LENGTH * 2;

    // verify PNG signature
    if (!std.mem.eql(u8, png_sig_slice, CONSTANTS.PNG_SIG)) {
        @panic("invalid PNG Header!");
    }

    try get_ihdr(allocator, &png, binary, &current_bit_position);
    try get_plte(allocator, &png, binary, &current_bit_position);
    try get_ancillary(allocator, &png, binary, &current_bit_position);

    var IDAT_CHUNKS = std.ArrayList(CRITICAL_CHUNK_TYPES.IDATStruct).init(allocator.*);
    while (!std.mem.eql(u8, binary[current_bit_position + CONSTANTS.BYTE_LENGTH .. current_bit_position + CONSTANTS.BYTE_LENGTH * 2], CONSTANTS.IEND_SIG)) {
        try get_idat(allocator, binary, &current_bit_position, &IDAT_CHUNKS, @intCast(IDAT_CHUNKS.items.len));
    }
    png.IDAT = IDAT_CHUNKS.items;

    return png;
}

pub fn get_ihdr(allocator: *std.mem.Allocator, png: *PNG_TYPES.PNGStruct, binary: []u8, cbp: *u32) !void {
    var current_bit_position = cbp.*;
    png.IHDR.crc = &[_]u8{};

    // INIT IHDR
    // get PNG IHDR size
    const ihdr_size_slice = binary[current_bit_position .. current_bit_position + CONSTANTS.BYTE_LENGTH];
    current_bit_position += CONSTANTS.BYTE_LENGTH;
    const ihdr_size = try LIB_CONVERSIONS.hex_to_int(allocator, ihdr_size_slice, u8);
    png.IHDR.size = ihdr_size;

    const ihdr_header_slice = binary[current_bit_position .. current_bit_position + CONSTANTS.BYTE_LENGTH];
    current_bit_position += CONSTANTS.BYTE_LENGTH;
    if (!std.mem.eql(u8, ihdr_header_slice, CONSTANTS.IHDR_SIG)) {
        @panic("not correct IHDR header!");
    }

    const ihdr_png_width = binary[current_bit_position .. current_bit_position + CONSTANTS.BYTE_LENGTH];
    current_bit_position += CONSTANTS.BYTE_LENGTH;
    const ihdr_png_height = binary[current_bit_position .. current_bit_position + CONSTANTS.BYTE_LENGTH];
    current_bit_position += CONSTANTS.BYTE_LENGTH;
    const ihdr_png_bbp = binary[current_bit_position .. current_bit_position + CONSTANTS.BIT_LENGTH * 2];
    current_bit_position += CONSTANTS.BIT_LENGTH * 2;
    const ihdr_png_ct = binary[current_bit_position .. current_bit_position + CONSTANTS.BIT_LENGTH * 2];
    current_bit_position += CONSTANTS.BIT_LENGTH * 2;
    const ihdr_png_cm = binary[current_bit_position .. current_bit_position + CONSTANTS.BIT_LENGTH * 2];
    current_bit_position += CONSTANTS.BIT_LENGTH * 2;
    const ihdr_png_fm = binary[current_bit_position .. current_bit_position + CONSTANTS.BIT_LENGTH * 2];
    current_bit_position += CONSTANTS.BIT_LENGTH * 2;
    const ihdr_png_ii = binary[current_bit_position .. current_bit_position + CONSTANTS.BIT_LENGTH * 2];
    current_bit_position += CONSTANTS.BIT_LENGTH * 2;
    const ihdr_png_crc = binary[current_bit_position .. current_bit_position + CONSTANTS.BYTE_LENGTH];
    current_bit_position += CONSTANTS.BYTE_LENGTH;

    // define IHDR
    png.IHDR.width = try LIB_CONVERSIONS.hex_to_int(allocator, ihdr_png_width, u16);
    png.IHDR.height = try LIB_CONVERSIONS.hex_to_int(allocator, ihdr_png_height, u16);
    png.IHDR.bits_per_pixel = try LIB_CONVERSIONS.hex_to_int(allocator, ihdr_png_bbp, u8);
    png.IHDR.color_type = try LIB_CONVERSIONS.hex_to_int(allocator, ihdr_png_ct, u8);
    png.IHDR.compression_method = try LIB_CONVERSIONS.hex_to_int(allocator, ihdr_png_cm, u8);
    png.IHDR.filter_method = try LIB_CONVERSIONS.hex_to_int(allocator, ihdr_png_fm, u8);
    png.IHDR.interlaced = try LIB_CONVERSIONS.hex_to_int(allocator, ihdr_png_ii, u8) == 1;
    png.IHDR.crc = ihdr_png_crc;

    cbp.* = current_bit_position;
}

pub fn get_plte(allocator: *std.mem.Allocator, png: *PNG_TYPES.PNGStruct, binary: []u8, cbp: *u32) !void {
    var current_bit_position = cbp.*;
    var rgb_array = std.ArrayList(PNG_TYPES.RGBStruct).init(allocator.*);

    png.PLTE.size = 0;
    png.PLTE.crc = &[_]u8{};

    // INIT PLTE
    plte_chunk: {
        if (png.IHDR.color_type == 0 or png.IHDR.color_type == 4) {
            break :plte_chunk;
        }

        const plte_size_slice = binary[current_bit_position .. current_bit_position + CONSTANTS.BYTE_LENGTH];
        current_bit_position += CONSTANTS.BYTE_LENGTH;

        const plte_header = binary[current_bit_position .. current_bit_position + CONSTANTS.BYTE_LENGTH];
        current_bit_position += CONSTANTS.BYTE_LENGTH;
        if (!std.mem.eql(u8, plte_header, CONSTANTS.PLTE_SIG)) {
            current_bit_position -= CONSTANTS.BYTE_LENGTH * 2;
            break :plte_chunk;
        }

        const plte_size = try LIB_CONVERSIONS.hex_to_int(allocator, plte_size_slice, u32);
        png.PLTE.size = plte_size;

        while (!std.mem.eql(u8, binary[current_bit_position + CONSTANTS.BYTE_LENGTH * 2 .. current_bit_position + CONSTANTS.BYTE_LENGTH * 3], CONSTANTS.IDAT_SIG)) {
            const red_palette_slice = binary[current_bit_position .. current_bit_position + CONSTANTS.BYTE_LENGTH];
            const green_palette_slice = binary[current_bit_position .. current_bit_position + CONSTANTS.BYTE_LENGTH];
            const blue_palette_slice = binary[current_bit_position .. current_bit_position + CONSTANTS.BYTE_LENGTH];

            const red_palette = try LIB_CONVERSIONS.hex_to_int(allocator, red_palette_slice, u8);
            const green_palette = try LIB_CONVERSIONS.hex_to_int(allocator, green_palette_slice, u8);
            const blue_palette = try LIB_CONVERSIONS.hex_to_int(allocator, blue_palette_slice, u8);

            const RGB: PNG_TYPES.RGBStruct = PNG_TYPES.RGBStruct{
                .R = red_palette,
                .G = green_palette,
                .B = blue_palette,
            };
            try rgb_array.append(RGB);
        }

        const plte_png_crc = binary[current_bit_position .. current_bit_position + CONSTANTS.BYTE_LENGTH];
        current_bit_position += CONSTANTS.BYTE_LENGTH;

        png.PLTE.crc = plte_png_crc;
    }

    if (rgb_array.items.len % 3 != 0) {
        @panic("invalid PLTE chunk!");
    }

    png.PLTE.rgb_array = rgb_array;
    cbp.* = current_bit_position;
}

pub fn get_ancillary(allocator: *std.mem.Allocator, png: *PNG_TYPES.PNGStruct, binary: []u8, cbp: *u32) !void {
    var current_bit_position = cbp.*;
    _ = png;

    // INIT ANCILLARY CHUNKS
    while (!std.mem.eql(u8, CONSTANTS.IDAT_SIG, binary[current_bit_position + CONSTANTS.BYTE_LENGTH .. current_bit_position + CONSTANTS.BYTE_LENGTH * 2])) {
        const new_header_size_slice = binary[current_bit_position .. current_bit_position + CONSTANTS.BYTE_LENGTH];
        const new_header_size = try LIB_CONVERSIONS.hex_to_int(allocator, new_header_size_slice, u32);
        current_bit_position += CONSTANTS.BYTE_LENGTH * 3 + (new_header_size * 2);
    }

    cbp.* = current_bit_position;
}

pub fn get_idat(allocator: *std.mem.Allocator, binary: []u8, cbp: *u32, idat_chunks: *std.ArrayList(CRITICAL_CHUNK_TYPES.IDATStruct), idat_index: u16) !void {
    var IDAT: CRITICAL_CHUNK_TYPES.IDATStruct = CRITICAL_CHUNK_TYPES.IDATStruct{ .compression_info = 0, .compression_method = 0, .crc = &[_]u8{}, .data = &[_]u8{}, .size = 0, .adler_zlib_checksum = 0, .zlib_fcheck_value = 0 };
    var current_bit_position = cbp.*;


    // INIT IDAT
    // get PNG IDAT size
    const idat_size_slice = binary[current_bit_position .. current_bit_position + CONSTANTS.BYTE_LENGTH];
    current_bit_position += CONSTANTS.BYTE_LENGTH;
    const idat_size = try LIB_CONVERSIONS.hex_to_int(allocator, idat_size_slice, u32);
    IDAT.size = idat_size;

    const idat_header_slice = binary[current_bit_position .. current_bit_position + CONSTANTS.BYTE_LENGTH];
    current_bit_position += CONSTANTS.BYTE_LENGTH;
    if (!std.mem.eql(u8, idat_header_slice, CONSTANTS.IDAT_SIG)) {
        @panic("not correct IDAT header!");
    }

    if (idat_index > 0) {
        const compressed_data = binary[current_bit_position .. current_bit_position + (idat_size * 2)];
        current_bit_position += (idat_size * 2); // =>  CRC

        var adler_zlib_checksum: u16 = 0;
        if (std.mem.eql(u8, binary[current_bit_position + CONSTANTS.BYTE_LENGTH * 3 .. current_bit_position + CONSTANTS.BYTE_LENGTH * 4], CONSTANTS.IEND_SIG)) {
            const adler_zlib_checksum_slice = binary[current_bit_position .. current_bit_position + CONSTANTS.BYTE_LENGTH];
            adler_zlib_checksum = try LIB_CONVERSIONS.hex_to_int(allocator, adler_zlib_checksum_slice, u16);
            current_bit_position += CONSTANTS.BYTE_LENGTH;
        }

        const idat_png_crc = binary[current_bit_position .. current_bit_position + CONSTANTS.BYTE_LENGTH];
        current_bit_position += CONSTANTS.BYTE_LENGTH;

        // define IDAT
        IDAT.compression_info = 0;
        IDAT.compression_method = 0;
        IDAT.zlib_fcheck_value = 0;
        IDAT.adler_zlib_checksum = adler_zlib_checksum;
        IDAT.crc = idat_png_crc;
        IDAT.data = compressed_data;

        try idat_chunks.append(IDAT);
        cbp.* = current_bit_position;
        return;
    }

    const deflate_compression = binary[current_bit_position .. current_bit_position + CONSTANTS.BIT_LENGTH * 2];
    current_bit_position += CONSTANTS.BIT_LENGTH * 2;
    const zlib_fcheck_value = binary[current_bit_position .. current_bit_position + CONSTANTS.BIT_LENGTH * 2];
    current_bit_position += CONSTANTS.BIT_LENGTH * 2;

    // validate the zlib header
    const validation_value_hex = try std.fmt.allocPrint(allocator.*, "{s}{s}", .{ deflate_compression, zlib_fcheck_value });

    const validation_value = try LIB_CONVERSIONS.hex_to_int(allocator, validation_value_hex, u16);
    if (validation_value % 31 != 0) {
        @panic("invalid zlib header!");
    }

    var adler_zlib_checksum: u16 = 0;
    if (std.mem.eql(u8, binary[current_bit_position + CONSTANTS.BYTE_LENGTH * 2 .. current_bit_position + CONSTANTS.BYTE_LENGTH * 3], CONSTANTS.IEND_SIG)) {
        const compressed_data = binary[current_bit_position .. current_bit_position + (idat_size * 2) - 12];
        current_bit_position += (idat_size * 2) - 12; // => ZLIB CHECK VALUE (2), COMPRESSION METHOD (2), ADLER32 (8)
        IDAT.data = compressed_data;

        const adler_zlib_checksum_slice = binary[current_bit_position .. current_bit_position + CONSTANTS.BYTE_LENGTH];
        adler_zlib_checksum = try LIB_CONVERSIONS.hex_to_int(allocator, adler_zlib_checksum_slice, u16);
        current_bit_position += CONSTANTS.BYTE_LENGTH;
    } else {
        const compressed_data = binary[current_bit_position .. current_bit_position + (idat_size * 2) - 4];
        current_bit_position += (idat_size * 2) - 4; // => ZLIB CHECK VALUE (2), COMPRESSION METHOD (2)
        IDAT.data = compressed_data;
    }

    const idat_png_crc = binary[current_bit_position .. current_bit_position + CONSTANTS.BYTE_LENGTH];
    current_bit_position += CONSTANTS.BYTE_LENGTH;

    // define IDAT
    IDAT.compression_info = try LIB_CONVERSIONS.hex_to_int(allocator, deflate_compression[0..1], u16);
    IDAT.compression_method = try LIB_CONVERSIONS.hex_to_int(allocator, deflate_compression[1..2], u8);
    IDAT.adler_zlib_checksum = adler_zlib_checksum;
    IDAT.zlib_fcheck_value = validation_value;
    IDAT.crc = idat_png_crc;

    try idat_chunks.append(IDAT);
    cbp.* = current_bit_position;
}
