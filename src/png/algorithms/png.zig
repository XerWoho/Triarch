const std = @import("std");
const PngTypes = @import("../types/png/png.zig");
const CriticalChunkTypes = @import("../types/png/chunks/critial.zig");
const AncillaryChunkTypes = @import("../types/png/chunks/ancillary.zig");

const Hex = @import("../lib/hex.zig");
const String = @import("../lib/string.zig");
const Conversions = @import("../lib/conversions.zig");
const Constants = @import("../constants.zig");

pub fn getPng(allocator: std.mem.Allocator, binary: []u8) !PngTypes.PNGStruct {
    var current_bit_position: u32 = 0;
    var png: PngTypes.PNGStruct = undefined;

    const png_sig_slice = binary[current_bit_position .. current_bit_position + Constants.BYTE_LENGTH * 2];
    current_bit_position += Constants.BYTE_LENGTH * 2;

    // verify PNG signature
    if (!std.mem.eql(u8, png_sig_slice, Constants.PNG_SIG)) {
        @panic("invalid PNG Header!");
    }

    try getIhdr(allocator, &png, binary, &current_bit_position);
    try getPlte(allocator, &png, binary, &current_bit_position);
    try getAncillary(allocator, &png, binary, &current_bit_position);

    var IDAT_CHUNKS = std.ArrayList(CriticalChunkTypes.IDATStruct).init(allocator);
    while (!std.mem.eql(u8, binary[current_bit_position + Constants.BYTE_LENGTH .. current_bit_position + Constants.BYTE_LENGTH * 2], Constants.IEND_SIG)) {
        try getIdat(allocator, binary, &current_bit_position, &IDAT_CHUNKS, @intCast(IDAT_CHUNKS.items.len));
    }
    png.IDAT = IDAT_CHUNKS.items;

    return png;
}

fn getIhdr(allocator: std.mem.Allocator, png: *PngTypes.PNGStruct, binary: []u8, cbp: *u32) !void {
    var current_bit_position = cbp.*;
    png.IHDR.crc = &[_]u8{};

    // INIT IHDR
    // get PNG IHDR size
    const ihdr_size_slice = binary[current_bit_position .. current_bit_position + Constants.BYTE_LENGTH];
    current_bit_position += Constants.BYTE_LENGTH;
    const ihdr_size = try Conversions.hexToInt(allocator, ihdr_size_slice, u8);
    png.IHDR.size = ihdr_size;

    const ihdr_header_slice = binary[current_bit_position .. current_bit_position + Constants.BYTE_LENGTH];
    current_bit_position += Constants.BYTE_LENGTH;
    if (!std.mem.eql(u8, ihdr_header_slice, Constants.IHDR_SIG)) {
        @panic("not correct IHDR header!");
    }

    const ihdr_png_width = binary[current_bit_position .. current_bit_position + Constants.BYTE_LENGTH];
    current_bit_position += Constants.BYTE_LENGTH;
    const ihdr_png_height = binary[current_bit_position .. current_bit_position + Constants.BYTE_LENGTH];
    current_bit_position += Constants.BYTE_LENGTH;
    const ihdr_png_bbp = binary[current_bit_position .. current_bit_position + Constants.BIT_LENGTH * 2];
    current_bit_position += Constants.BIT_LENGTH * 2;
    const ihdr_png_ct = binary[current_bit_position .. current_bit_position + Constants.BIT_LENGTH * 2];
    current_bit_position += Constants.BIT_LENGTH * 2;
    const ihdr_png_cm = binary[current_bit_position .. current_bit_position + Constants.BIT_LENGTH * 2];
    current_bit_position += Constants.BIT_LENGTH * 2;
    const ihdr_png_fm = binary[current_bit_position .. current_bit_position + Constants.BIT_LENGTH * 2];
    current_bit_position += Constants.BIT_LENGTH * 2;
    const ihdr_png_ii = binary[current_bit_position .. current_bit_position + Constants.BIT_LENGTH * 2];
    current_bit_position += Constants.BIT_LENGTH * 2;
    const ihdr_png_crc = binary[current_bit_position .. current_bit_position + Constants.BYTE_LENGTH];
    current_bit_position += Constants.BYTE_LENGTH;

    // define IHDR
    png.IHDR.width = try Conversions.hexToInt(allocator, ihdr_png_width, u16);
    png.IHDR.height = try Conversions.hexToInt(allocator, ihdr_png_height, u16);
    png.IHDR.bits_per_pixel = try Conversions.hexToInt(allocator, ihdr_png_bbp, u8);
    png.IHDR.color_type = try Conversions.hexToInt(allocator, ihdr_png_ct, u8);
    png.IHDR.compression_method = try Conversions.hexToInt(allocator, ihdr_png_cm, u8);
    png.IHDR.filter_method = try Conversions.hexToInt(allocator, ihdr_png_fm, u8);
    png.IHDR.interlaced = try Conversions.hexToInt(allocator, ihdr_png_ii, u8) == 1;
    png.IHDR.crc = ihdr_png_crc;

    cbp.* = current_bit_position;
}

fn getPlte(allocator: std.mem.Allocator, png: *PngTypes.PNGStruct, binary: []u8, cbp: *u32) !void {
    var current_bit_position = cbp.*;
    var rgb_array = std.ArrayList(PngTypes.RGBStruct).init(allocator);

    png.PLTE.size = 0;
    png.PLTE.crc = &[_]u8{};

    // INIT PLTE
    plte_chunk: {
        if (png.IHDR.color_type == 0 or png.IHDR.color_type == 4) {
            break :plte_chunk;
        }

        const plte_size_slice = binary[current_bit_position .. current_bit_position + Constants.BYTE_LENGTH];
        current_bit_position += Constants.BYTE_LENGTH;

        const plte_header = binary[current_bit_position .. current_bit_position + Constants.BYTE_LENGTH];
        current_bit_position += Constants.BYTE_LENGTH;
        if (!std.mem.eql(u8, plte_header, Constants.PLTE_SIG)) {
            current_bit_position -= Constants.BYTE_LENGTH * 2;
            break :plte_chunk;
        }

        const plte_size = try Conversions.hexToInt(allocator, plte_size_slice, u32);
        png.PLTE.size = plte_size;

        while (!std.mem.eql(u8, binary[current_bit_position + Constants.BYTE_LENGTH * 2 .. current_bit_position + Constants.BYTE_LENGTH * 3], Constants.IDAT_SIG)) {
            const red_palette_slice = binary[current_bit_position .. current_bit_position + Constants.BYTE_LENGTH];
            const green_palette_slice = binary[current_bit_position .. current_bit_position + Constants.BYTE_LENGTH];
            const blue_palette_slice = binary[current_bit_position .. current_bit_position + Constants.BYTE_LENGTH];

            const red_palette = try Conversions.hexToInt(allocator, red_palette_slice, u8);
            const green_palette = try Conversions.hexToInt(allocator, green_palette_slice, u8);
            const blue_palette = try Conversions.hexToInt(allocator, blue_palette_slice, u8);

            const RGB: PngTypes.RGBStruct = PngTypes.RGBStruct{
                .R = red_palette,
                .G = green_palette,
                .B = blue_palette,
            };
            try rgb_array.append(RGB);
        }

        const plte_png_crc = binary[current_bit_position .. current_bit_position + Constants.BYTE_LENGTH];
        current_bit_position += Constants.BYTE_LENGTH;

        png.PLTE.crc = plte_png_crc;
    }

    if (rgb_array.items.len % 3 != 0) {
        @panic("invalid PLTE chunk!");
    }

    png.PLTE.rgb_array = rgb_array;
    cbp.* = current_bit_position;
}

fn getAncillary(allocator: std.mem.Allocator, png: *PngTypes.PNGStruct, binary: []u8, cbp: *u32) !void {
    var current_bit_position = cbp.*;
    _ = png;

    // INIT ANCILLARY CHUNKS
    while (!std.mem.eql(u8, Constants.IDAT_SIG, binary[current_bit_position + Constants.BYTE_LENGTH .. current_bit_position + Constants.BYTE_LENGTH * 2])) {
        const ancillary_header_size_slice = binary[current_bit_position .. current_bit_position + Constants.BYTE_LENGTH];
        const ancillary_header_size = try Conversions.hexToInt(allocator, ancillary_header_size_slice, u32);
        current_bit_position += Constants.BYTE_LENGTH;

        const ancillary_header_slice = binary[current_bit_position..current_bit_position + Constants.BYTE_LENGTH];
        _ = ancillary_header_slice;
        current_bit_position += Constants.BYTE_LENGTH;

        const ancillary_header_data = binary[current_bit_position..current_bit_position + 2 * ancillary_header_size];
        _ = ancillary_header_data;
        current_bit_position += 2 * ancillary_header_size;
        // std.debug.print("{s}\n", .{ancillary_header_data});
        // if(std.mem.eql(u8, ancillary_header_slice, Constants.sRGB_SIG)) {
        //     const srgb_rendering_intent = try Conversions.hexToInt(allocator, ancillary_header_data, u32);
        // }
        // if(std.mem.eql(u8, ancillary_header_slice, Constants.pHYs_SIG)) {
        //     const pixels_unit_x = try Conversions.hexToInt(allocator, ancillary_header_data[0..8], u32);
        //     const pixels_unit_y = try Conversions.hexToInt(allocator, ancillary_header_data[8..16], u32);
        //     const pixels_unit_specifier = try Conversions.hexToInt(allocator, ancillary_header_data[16..18], u32);
        // }
        // if(std.mem.eql(u8, ancillary_header_slice, Constants.gAMA_SIG)) {
        //     const gama_value = try Conversions.hexToInt(allocator, ancillary_header_data, u32);
        // }

        const ancillary_header_crc = binary[current_bit_position..current_bit_position + Constants.BYTE_LENGTH];
        _ = ancillary_header_crc;
        current_bit_position += Constants.BYTE_LENGTH;
    }


    cbp.* = current_bit_position;
}

fn getIdat(allocator: std.mem.Allocator, binary: []u8, cbp: *u32, idat_chunks: *std.ArrayList(CriticalChunkTypes.IDATStruct), idat_index: u16) !void {
    var IDAT: CriticalChunkTypes.IDATStruct = CriticalChunkTypes.IDATStruct{ .compression_info = 0, .compression_method = 0, .crc = &[_]u8{}, .data = &[_]u8{}, .size = 0, .adler_zlib_checksum = 0, .zlib_fcheck_value = 0 };
    var current_bit_position = cbp.*;


    // INIT IDAT
    // get PNG IDAT size
    const idat_size_slice = binary[current_bit_position .. current_bit_position + Constants.BYTE_LENGTH];
    current_bit_position += Constants.BYTE_LENGTH;
    const idat_size = try Conversions.hexToInt(allocator, idat_size_slice, u32);
    IDAT.size = idat_size;

    const idat_header_slice = binary[current_bit_position .. current_bit_position + Constants.BYTE_LENGTH];
    current_bit_position += Constants.BYTE_LENGTH;
    if (!std.mem.eql(u8, idat_header_slice, Constants.IDAT_SIG)) {
        @panic("not correct IDAT header!");
    }

    if (idat_index > 0) {
        const compressed_data = binary[current_bit_position .. current_bit_position + (idat_size * 2)];
        current_bit_position += (idat_size * 2); // =>  CRC

        var adler_zlib_checksum: u16 = 0;
        if (std.mem.eql(u8, binary[current_bit_position + Constants.BYTE_LENGTH * 3 .. current_bit_position + Constants.BYTE_LENGTH * 4], Constants.IEND_SIG)) {
            const adler_zlib_checksum_slice = binary[current_bit_position .. current_bit_position + Constants.BYTE_LENGTH];
            adler_zlib_checksum = try Conversions.hexToInt(allocator, adler_zlib_checksum_slice, u16);
            current_bit_position += Constants.BYTE_LENGTH;
        }

        const idat_png_crc = binary[current_bit_position .. current_bit_position + Constants.BYTE_LENGTH];
        current_bit_position += Constants.BYTE_LENGTH;

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

    const deflate_compression = binary[current_bit_position .. current_bit_position + Constants.BIT_LENGTH * 2];
    current_bit_position += Constants.BIT_LENGTH * 2;
    const zlib_fcheck_value = binary[current_bit_position .. current_bit_position + Constants.BIT_LENGTH * 2];
    current_bit_position += Constants.BIT_LENGTH * 2;

    // validate the zlib header
    const validation_value_hex = try std.fmt.allocPrint(allocator, "{s}{s}", .{ deflate_compression, zlib_fcheck_value });

    const validation_value = try Conversions.hexToInt(allocator, validation_value_hex, u16);
    if (validation_value % 31 != 0) {
        @panic("invalid zlib header!");
    }

    var adler_zlib_checksum: u16 = 0;
    if (std.mem.eql(u8, binary[current_bit_position + Constants.BYTE_LENGTH * 2 .. current_bit_position + Constants.BYTE_LENGTH * 3], Constants.IEND_SIG)) {
        const compressed_data = binary[current_bit_position .. current_bit_position + (idat_size * 2) - 12];
        current_bit_position += (idat_size * 2) - 12; // => ZLIB CHECK VALUE (2), COMPRESSION METHOD (2), ADLER32 (8)
        IDAT.data = compressed_data;

        const adler_zlib_checksum_slice = binary[current_bit_position .. current_bit_position + Constants.BYTE_LENGTH];
        adler_zlib_checksum = try Conversions.hexToInt(allocator, adler_zlib_checksum_slice, u16);
        current_bit_position += Constants.BYTE_LENGTH;
    } else {
        const compressed_data = binary[current_bit_position .. current_bit_position + (idat_size * 2) - 4];
        current_bit_position += (idat_size * 2) - 4; // => ZLIB CHECK VALUE (2), COMPRESSION METHOD (2)
        IDAT.data = compressed_data;
    }

    const idat_png_crc = binary[current_bit_position .. current_bit_position + Constants.BYTE_LENGTH];
    current_bit_position += Constants.BYTE_LENGTH;

    // define IDAT
    IDAT.compression_info = try Conversions.hexToInt(allocator, deflate_compression[0..1], u16);
    IDAT.compression_method = try Conversions.hexToInt(allocator, deflate_compression[1..2], u8);
    IDAT.adler_zlib_checksum = adler_zlib_checksum;
    IDAT.zlib_fcheck_value = validation_value;
    IDAT.crc = idat_png_crc;

    try idat_chunks.append(IDAT);
    cbp.* = current_bit_position;
}
