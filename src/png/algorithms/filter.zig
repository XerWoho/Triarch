const std = @import("std");
const PngTypes = @import("../types/png/png.zig");
const PixelTypes = @import("../types/pixels.zig");

pub fn getFilter(allocator: std.mem.Allocator, uncompressed_data: std.ArrayList(u8), png: *PngTypes.PNGStruct) !std.ArrayList(PixelTypes.PixelStruct) {
    const image_width = png.IHDR.width;
    const image_height = png.IHDR.height;

    return switch (png.IHDR.color_type) {
        0 => try getFilterGrayscale(allocator, uncompressed_data.items, image_height, (1 + (image_width * 1))),
        2 => return try getFilterRgb(allocator, uncompressed_data.items, image_height, (1 + (image_width * 3))),
        4 => return try getFilterGrayscaleA(allocator, uncompressed_data.items, image_height, (1 + (image_width * 2))),
        6 => return try getFilterRgbA(allocator, uncompressed_data.items, image_height, (1 + (image_width * 4))),
        else => @panic("invalid type"),
    };
}

fn getFilterRgbA(allocator: std.mem.Allocator, uncompressed_data: []u8, image_height: u64, row_size: u64) !std.ArrayList(PixelTypes.PixelStruct) {
    var pixels_wrapper = std.ArrayList(PixelTypes.PixelStruct).init(allocator);
    const uncompressed = uncompressed_data;

    var current_filter_method: u8 = 0;
    var height_index: u64 = 0;
    for (0..image_height) |_| {
        var row_index: u64 = 0;
        while (true) {
            const bit_index = height_index * row_size + row_index;

            if (bit_index >= row_size * (height_index + 1)) break;
            if (bit_index >= uncompressed.len) break;
            if (row_index == 0) {
                current_filter_method = uncompressed[bit_index];
                row_index += 1;
                continue;
            }

            if (current_filter_method == 0) { // NO FILTER
                const r_bit = uncompressed[bit_index];
                const g_bit = uncompressed[bit_index + 1];
                const b_bit = uncompressed[bit_index + 2];
                const a_bit = uncompressed[bit_index + 3];

                const current_pixel = PixelTypes.PixelStruct{ .R = r_bit, .G = g_bit, .B = b_bit, .A = a_bit, .COLUMN_INDEX = height_index, .ROW_INDEX = @divTrunc((row_index - 1), 4) };

                try pixels_wrapper.append(current_pixel);
                row_index += 4;
                continue;
            }

            var u16_r_bit: u16 = uncompressed[bit_index];
            var u16_g_bit: u16 = uncompressed[bit_index + 1];
            var u16_b_bit: u16 = uncompressed[bit_index + 2];
            var u16_a_bit: u16 = uncompressed[bit_index + 3];

            if (current_filter_method == 1) {
                var previous_r_bit: u16 = 0;
                var previous_g_bit: u16 = 0;
                var previous_b_bit: u16 = 0;
                var previous_a_bit: u16 = 0;

                if (row_index >= 4) {
                    previous_r_bit = uncompressed[bit_index - 4];
                    previous_g_bit = uncompressed[bit_index - 3];
                    previous_b_bit = uncompressed[bit_index - 2];
                    previous_a_bit = uncompressed[bit_index - 1];
                }

                u16_r_bit = @intCast(@mod(u16_r_bit + previous_r_bit, 256));
                u16_g_bit = @intCast(@mod(u16_g_bit + previous_g_bit, 256));
                u16_b_bit = @intCast(@mod(u16_b_bit + previous_b_bit, 256));
                u16_a_bit = @intCast(@mod(u16_a_bit + previous_a_bit, 256));
            } else if (current_filter_method == 2) {
                const row_move_up = height_index * row_size;
                var top_r_bit: u16 = 0;
                var top_g_bit: u16 = 0;
                var top_b_bit: u16 = 0;
                var top_a_bit: u16 = 0;

                if (height_index > 0) {
                    top_r_bit = uncompressed[bit_index - row_move_up];
                    top_g_bit = uncompressed[bit_index + 1 - row_move_up];
                    top_b_bit = uncompressed[bit_index + 2 - row_move_up];
                    top_a_bit = uncompressed[bit_index + 3 - row_move_up];
                }

                u16_r_bit = @intCast(@mod(u16_r_bit + top_r_bit, 256));
                u16_g_bit = @intCast(@mod(u16_g_bit + top_g_bit, 256));
                u16_b_bit = @intCast(@mod(u16_b_bit + top_b_bit, 256));
                u16_a_bit = @intCast(@mod(u16_a_bit + top_a_bit, 256));
            } else if (current_filter_method == 3) {
                var previous_r_bit: u16 = 0;
                var previous_g_bit: u16 = 0;
                var previous_b_bit: u16 = 0;
                var previous_a_bit: u16 = 0;

                if (row_index >= 4) {
                    previous_r_bit = uncompressed[bit_index - 4];
                    previous_g_bit = uncompressed[bit_index - 3];
                    previous_b_bit = uncompressed[bit_index - 2];
                    previous_a_bit = uncompressed[bit_index - 1];
                }

                const row_move_up = height_index * row_size;
                var top_r_bit: u16 = 0;
                var top_g_bit: u16 = 0;
                var top_b_bit: u16 = 0;
                var top_a_bit: u16 = 0;

                if (height_index > 0) {
                    top_r_bit = uncompressed[bit_index - row_move_up];
                    top_g_bit = uncompressed[bit_index + 1 - row_move_up];
                    top_b_bit = uncompressed[bit_index + 2 - row_move_up];
                    top_a_bit = uncompressed[bit_index + 3 - row_move_up];
                }

                u16_r_bit = @intCast(@mod(u16_r_bit + @divTrunc((top_r_bit + previous_r_bit), 2), 256));
                u16_g_bit = @intCast(@mod(u16_g_bit + @divTrunc((top_g_bit + previous_g_bit), 2), 256));
                u16_b_bit = @intCast(@mod(u16_b_bit + @divTrunc((top_b_bit + previous_b_bit), 2), 256));
                u16_a_bit = @intCast(@mod(u16_a_bit + @divTrunc((top_a_bit + previous_a_bit), 2), 256));
            } else if (current_filter_method == 4) {
                var previous_r_bit: u16 = 0;
                var previous_g_bit: u16 = 0;
                var previous_b_bit: u16 = 0;
                var previous_a_bit: u16 = 0;

                if (row_index >= 1) {
                    previous_r_bit = uncompressed[bit_index - 4];
                    previous_g_bit = uncompressed[bit_index - 3];
                    previous_b_bit = uncompressed[bit_index - 2];
                    previous_a_bit = uncompressed[bit_index - 1];
                }

                const row_move_up = height_index * row_size;
                var top_r_bit: u16 = 0;
                var top_g_bit: u16 = 0;
                var top_b_bit: u16 = 0;
                var top_a_bit: u16 = 0;

                if (height_index > 0) {
                    top_r_bit = uncompressed[bit_index - row_move_up];
                    top_g_bit = uncompressed[bit_index + 1 - row_move_up];
                    top_b_bit = uncompressed[bit_index + 2 - row_move_up];
                    top_a_bit = uncompressed[bit_index + 3 - row_move_up];
                }

                var top_left_r_bit: u16 = 0;
                var top_left_g_bit: u16 = 0;
                var top_left_b_bit: u16 = 0;
                var top_left_a_bit: u16 = 0;

                if (height_index > 0 and row_index >= 4) {
                    top_left_r_bit = uncompressed[bit_index - row_move_up - 1];
                    top_left_g_bit = uncompressed[bit_index + 1 - row_move_up - 1];
                    top_left_b_bit = uncompressed[bit_index + 2 - row_move_up - 1];
                    top_left_a_bit = uncompressed[bit_index + 3 - row_move_up - 1];
                }

                const r_bit_p = previous_r_bit + top_r_bit - top_left_r_bit;
                const r_bit_a = @abs(r_bit_p - previous_r_bit);
                const r_bit_b = @abs(r_bit_p - top_r_bit);
                const r_bit_c = @abs(r_bit_p - top_left_r_bit);
                if (r_bit_a <= r_bit_b and r_bit_a <= r_bit_c) {
                    u16_r_bit = @intCast(@mod(u16_r_bit + r_bit_a, 256));
                } else if (r_bit_b <= r_bit_c) {
                    u16_r_bit = @intCast(@mod(u16_r_bit + r_bit_b, 256));
                } else {
                    u16_r_bit = @intCast(@mod(u16_r_bit + r_bit_c, 256));
                }

                const g_bit_p = previous_g_bit + top_g_bit - top_left_g_bit;
                const g_bit_a = @abs(g_bit_p - previous_g_bit);
                const g_bit_b = @abs(g_bit_p - top_g_bit);
                const g_bit_c = @abs(g_bit_p - top_left_g_bit);
                if (g_bit_a <= g_bit_b and g_bit_a <= g_bit_c) {
                    u16_g_bit = @intCast(@mod(u16_g_bit + g_bit_a, 256));
                } else if (g_bit_b <= g_bit_c) {
                    u16_g_bit = @intCast(@mod(u16_g_bit + g_bit_b, 256));
                } else {
                    u16_g_bit = @intCast(@mod(u16_g_bit + g_bit_c, 256));
                }

                const b_bit_p = previous_b_bit + top_b_bit - top_left_b_bit;
                const b_bit_a = @abs(b_bit_p - previous_b_bit);
                const b_bit_b = @abs(b_bit_p - top_b_bit);
                const b_bit_c = @abs(b_bit_p - top_left_b_bit);
                if (b_bit_a <= b_bit_b and b_bit_a <= b_bit_c) {
                    u16_b_bit = @intCast(@mod(u16_b_bit + b_bit_a, 256));
                } else if (b_bit_b <= b_bit_c) {
                    u16_b_bit = @intCast(@mod(u16_b_bit + b_bit_b, 256));
                } else {
                    u16_b_bit = @intCast(@mod(u16_b_bit + b_bit_c, 256));
                }

                const a_bit_p = previous_a_bit + top_a_bit - top_left_a_bit;
                const a_bit_a = @abs(a_bit_p - previous_a_bit);
                const a_bit_b = @abs(a_bit_p - top_a_bit);
                const a_bit_c = @abs(a_bit_p - top_left_a_bit);
                if (a_bit_a <= a_bit_b and a_bit_a <= a_bit_c) {
                    u16_a_bit = @intCast(@mod(u16_a_bit + a_bit_a, 256));
                } else if (a_bit_b <= a_bit_c) {
                    u16_a_bit = @intCast(@mod(u16_a_bit + a_bit_b, 256));
                } else {
                    u16_a_bit = @intCast(@mod(u16_a_bit + a_bit_c, 256));
                }
            }

            const r_bit: u8 = @intCast(u16_r_bit);
            const g_bit: u8 = @intCast(u16_g_bit);
            const b_bit: u8 = @intCast(u16_b_bit);
            const a_bit: u8 = @intCast(u16_a_bit);

            uncompressed[bit_index] = r_bit;
            uncompressed[bit_index + 1] = g_bit;
            uncompressed[bit_index + 2] = b_bit;
            uncompressed[bit_index + 3] = a_bit;
            const current_pixel = PixelTypes.PixelStruct{ .R = r_bit, .G = g_bit, .B = b_bit, .A = a_bit, .COLUMN_INDEX = height_index, .ROW_INDEX = @divTrunc((row_index - 1), 4) };

            try pixels_wrapper.append(current_pixel);
            row_index += 4;
        }
        height_index += 1;
    }

    return pixels_wrapper;
}

fn getFilterRgb(allocator: std.mem.Allocator, uncompressed_data: []u8, image_height: u64, row_size: u64) !std.ArrayList(PixelTypes.PixelStruct) {
    var pixels_wrapper = std.ArrayList(PixelTypes.PixelStruct).init(allocator);
    const uncompressed = uncompressed_data;

    var current_filter_method: u8 = 0;
    var height_index: u64 = 0;
    for (0..image_height) |_| {
        var row_index: u64 = 0;
        while (true) {
            const bit_index = height_index * row_size + row_index;

            if (bit_index >= row_size * (height_index + 1)) break;
            if (bit_index >= uncompressed.len) break;
            if (row_index == 0) {
                current_filter_method = uncompressed[bit_index];
                row_index += 1;
                continue;
            }

            if (current_filter_method == 0) { // NO FILTER
                const r_bit = uncompressed[bit_index];
                const g_bit = uncompressed[bit_index + 1];
                const b_bit = uncompressed[bit_index + 2];

                const current_pixel = PixelTypes.PixelStruct{ .R = r_bit, .G = g_bit, .B = b_bit, .A = 255, .COLUMN_INDEX = height_index, .ROW_INDEX = @divTrunc((row_index - 1), 4) };

                try pixels_wrapper.append(current_pixel);
                row_index += 3;
                continue;
            }

            var u16_r_bit: u16 = uncompressed[bit_index];
            var u16_g_bit: u16 = uncompressed[bit_index + 1];
            var u16_b_bit: u16 = uncompressed[bit_index + 2];

            if (current_filter_method == 1) {
                var previous_r_bit: u16 = 0;
                var previous_g_bit: u16 = 0;
                var previous_b_bit: u16 = 0;

                if (row_index >= 3) {
                    previous_r_bit = uncompressed[bit_index - 3];
                    previous_g_bit = uncompressed[bit_index - 2];
                    previous_b_bit = uncompressed[bit_index - 1];
                }

                u16_r_bit = @intCast(@mod(u16_r_bit + previous_r_bit, 256));
                u16_g_bit = @intCast(@mod(u16_g_bit + previous_g_bit, 256));
                u16_b_bit = @intCast(@mod(u16_b_bit + previous_b_bit, 256));
            } else if (current_filter_method == 2) {
                const row_move_up = height_index * row_size;
                var top_r_bit: u16 = 0;
                var top_g_bit: u16 = 0;
                var top_b_bit: u16 = 0;

                if (height_index > 0) {
                    top_r_bit = uncompressed[bit_index - row_move_up];
                    top_g_bit = uncompressed[bit_index + 1 - row_move_up];
                    top_b_bit = uncompressed[bit_index + 2 - row_move_up];
                }

                u16_r_bit = @intCast(@mod(u16_r_bit + top_r_bit, 256));
                u16_g_bit = @intCast(@mod(u16_g_bit + top_g_bit, 256));
                u16_b_bit = @intCast(@mod(u16_b_bit + top_b_bit, 256));
            } else if (current_filter_method == 3) {
                var previous_r_bit: u16 = 0;
                var previous_g_bit: u16 = 0;
                var previous_b_bit: u16 = 0;

                if (row_index >= 3) {
                    previous_r_bit = uncompressed[bit_index - 3];
                    previous_g_bit = uncompressed[bit_index - 2];
                    previous_b_bit = uncompressed[bit_index - 1];
                }

                const row_move_up = height_index * row_size;
                var top_r_bit: u16 = 0;
                var top_g_bit: u16 = 0;
                var top_b_bit: u16 = 0;

                if (height_index > 0) {
                    top_r_bit = uncompressed[bit_index - row_move_up];
                    top_g_bit = uncompressed[bit_index + 1 - row_move_up];
                    top_b_bit = uncompressed[bit_index + 2 - row_move_up];
                }

                u16_r_bit = @intCast(@mod(u16_r_bit + @divTrunc((top_r_bit + previous_r_bit), 2), 256));
                u16_g_bit = @intCast(@mod(u16_g_bit + @divTrunc((top_g_bit + previous_g_bit), 2), 256));
                u16_b_bit = @intCast(@mod(u16_b_bit + @divTrunc((top_b_bit + previous_b_bit), 2), 256));
            } else if (current_filter_method == 4) {
                var previous_r_bit: i16 = 0;
                var previous_g_bit: i16 = 0;
                var previous_b_bit: i16 = 0;

                if (row_index >= 1) {
                    previous_r_bit = uncompressed[bit_index - 3];
                    previous_g_bit = uncompressed[bit_index - 2];
                    previous_b_bit = uncompressed[bit_index - 1];
                }

                const row_move_up = height_index * row_size;
                var top_r_bit: i16 = 0;
                var top_g_bit: i16 = 0;
                var top_b_bit: i16 = 0;

                if (height_index > 0) {
                    top_r_bit = uncompressed[bit_index - row_move_up];
                    top_g_bit = uncompressed[bit_index + 1 - row_move_up];
                    top_b_bit = uncompressed[bit_index + 2 - row_move_up];
                }

                var top_left_r_bit: i16 = 0;
                var top_left_g_bit: i16 = 0;
                var top_left_b_bit: i16 = 0;

                if (height_index > 0 and row_index >= 4) {
                    top_left_r_bit = uncompressed[bit_index - row_move_up - 1];
                    top_left_g_bit = uncompressed[bit_index + 1 - row_move_up - 1];
                    top_left_b_bit = uncompressed[bit_index + 2 - row_move_up - 1];
                }

                const r_bit_P: i16 = previous_r_bit + top_r_bit - top_left_r_bit;
                const r_bit_A = @abs(r_bit_P - previous_r_bit);
                const r_bit_B = @abs(r_bit_P - top_r_bit);
                const r_bit_C = @abs(r_bit_P - top_left_r_bit);
                if (r_bit_A <= r_bit_B and r_bit_A <= r_bit_C) {
                    u16_r_bit = @intCast(@mod(u16_r_bit + r_bit_A, 256));
                } else if (r_bit_B <= r_bit_C) {
                    u16_r_bit = @intCast(@mod(u16_r_bit + r_bit_B, 256));
                } else {
                    u16_r_bit = @intCast(@mod(u16_r_bit + r_bit_C, 256));
                }

                const g_bit_P: i16 = previous_g_bit + top_g_bit - top_left_g_bit;
                const g_bit_A = @abs(g_bit_P - previous_g_bit);
                const g_bit_B = @abs(g_bit_P - top_g_bit);
                const g_bit_C = @abs(g_bit_P - top_left_g_bit);
                if (g_bit_A <= g_bit_B and g_bit_A <= g_bit_C) {
                    u16_g_bit = @intCast(@mod(u16_g_bit + g_bit_A, 256));
                } else if (g_bit_B <= g_bit_C) {
                    u16_g_bit = @intCast(@mod(u16_g_bit + g_bit_B, 256));
                } else {
                    u16_g_bit = @intCast(@mod(u16_g_bit + g_bit_C, 256));
                }

                const b_bit_P: i16 = previous_b_bit + top_b_bit - top_left_b_bit;
                const b_bit_A = @abs(b_bit_P - previous_b_bit);
                const b_bit_B = @abs(b_bit_P - top_b_bit);
                const b_bit_C = @abs(b_bit_P - top_left_b_bit);
                if (b_bit_A <= b_bit_B and b_bit_A <= b_bit_C) {
                    u16_b_bit = @intCast(@mod(u16_b_bit + b_bit_A, 256));
                } else if (b_bit_B <= b_bit_C) {
                    u16_b_bit = @intCast(@mod(u16_b_bit + b_bit_B, 256));
                } else {
                    u16_b_bit = @intCast(@mod(u16_b_bit + b_bit_C, 256));
                }
            }

            const r_bit: u8 = @intCast(u16_r_bit);
            const g_bit: u8 = @intCast(u16_g_bit);
            const b_bit: u8 = @intCast(u16_b_bit);

            uncompressed[bit_index] = r_bit;
            uncompressed[bit_index + 1] = g_bit;
            uncompressed[bit_index + 2] = b_bit;
            const current_pixel = PixelTypes.PixelStruct{ .R = r_bit, .G = g_bit, .B = b_bit, .A = 255, .COLUMN_INDEX = height_index, .ROW_INDEX = @divTrunc((row_index - 1), 4) };

            try pixels_wrapper.append(current_pixel);
            row_index += 3;
        }
        height_index += 1;
    }

    return pixels_wrapper;
}

fn getFilterGrayscale(allocator: std.mem.Allocator, uncompressed_data: []u8, image_height: u64, row_size: u64) !std.ArrayList(PixelTypes.PixelStruct) {
    var pixels_wrapper = std.ArrayList(PixelTypes.PixelStruct).init(allocator);
    const uncompressed = uncompressed_data;

    var current_filter_method: u8 = 0;
    var height_index: u64 = 0;
    for (0..image_height) |_| {
        var row_index: u64 = 0;
        while (true) {
            const bit_index = height_index * row_size + row_index;

            if (bit_index >= row_size * (height_index + 1)) break;
            if (bit_index >= uncompressed.len) break;
            if (row_index == 0) {
                current_filter_method = uncompressed[bit_index];
                row_index += 1;
                continue;
            }

            if (current_filter_method == 0) { // NO FILTER
                const gray_scale = uncompressed[bit_index];
                const current_pixel = PixelTypes.PixelStruct{ .R = gray_scale, .G = gray_scale, .B = gray_scale, .A = 255, .COLUMN_INDEX = height_index, .ROW_INDEX = @divTrunc((row_index - 1), 4) };

                try pixels_wrapper.append(current_pixel);
                row_index += 1;
                continue;
            }

            var u16_gray_scale: u16 = uncompressed[bit_index];

            if (current_filter_method == 1) {
                var previous_gray_scale_bit: u16 = 0;

                if (row_index >= 1) {
                    previous_gray_scale_bit = uncompressed[bit_index - 1];
                }

                u16_gray_scale = @intCast(@mod(u16_gray_scale + previous_gray_scale_bit, 256));
            } else if (current_filter_method == 2) {
                const row_move_up = height_index * row_size;
                var top_gray_scale_bit: u16 = 0;

                if (height_index > 0) {
                    top_gray_scale_bit = uncompressed[bit_index - row_move_up];
                }

                u16_gray_scale = @intCast(@mod(u16_gray_scale + top_gray_scale_bit, 256));
            } else if (current_filter_method == 3) {
                var previous_gray_scale_bit: u16 = 0;

                if (row_index >= 1) {
                    previous_gray_scale_bit = uncompressed[bit_index - 1];
                }

                const row_move_up = height_index * row_size;
                var top_gray_scale_bit: u16 = 0;

                if (height_index > 0) {
                    top_gray_scale_bit = uncompressed[bit_index - row_move_up];
                }

                u16_gray_scale = @intCast(@mod(u16_gray_scale + @divTrunc((top_gray_scale_bit + previous_gray_scale_bit), 2), 256));
            } else if (current_filter_method == 4) {
                var previous_gray_scale_bit: i16 = 0;

                if (row_index >= 1) {
                    previous_gray_scale_bit = uncompressed[bit_index - 1];
                }

                const row_move_up = height_index * row_size;
                var top_gray_scale_bit: i16 = 0;

                if (height_index > 0) {
                    top_gray_scale_bit = uncompressed[bit_index - row_move_up];
                }

                var top_left_gray_scale_bit: i16 = 0;

                if (height_index > 0 and row_index >= 1) {
                    top_left_gray_scale_bit = uncompressed[bit_index - row_move_up - 1];
                }

                const gray_scale_bit_p: i16 = previous_gray_scale_bit + top_gray_scale_bit - top_left_gray_scale_bit;
                const gray_scale_bit_a = @abs(gray_scale_bit_p - previous_gray_scale_bit);
                const gray_scale_bit_b = @abs(gray_scale_bit_p - top_gray_scale_bit);
                const gray_scale_bit_c = @abs(gray_scale_bit_p - top_left_gray_scale_bit);
                if (gray_scale_bit_a <= gray_scale_bit_b and gray_scale_bit_a <= gray_scale_bit_c) {
                    u16_gray_scale = @intCast(@mod(u16_gray_scale + gray_scale_bit_a, 256));
                } else if (gray_scale_bit_b <= gray_scale_bit_c) {
                    u16_gray_scale = @intCast(@mod(u16_gray_scale + gray_scale_bit_b, 256));
                } else {
                    u16_gray_scale = @intCast(@mod(u16_gray_scale + gray_scale_bit_c, 256));
                }
            }

            const gray_scale: u8 = @intCast(u16_gray_scale);

            uncompressed[bit_index] = gray_scale;
            const current_pixel = PixelTypes.PixelStruct{ .R = gray_scale, .G = gray_scale, .B = gray_scale, .A = 255, .COLUMN_INDEX = height_index, .ROW_INDEX = @divTrunc((row_index - 1), 4) };

            try pixels_wrapper.append(current_pixel);
            row_index += 1;
        }
        height_index += 1;
    }

    return pixels_wrapper;
}

fn getFilterGrayscaleA(allocator: std.mem.Allocator, uncompressed_data: []u8, image_height: u64, row_size: u64) !std.ArrayList(PixelTypes.PixelStruct) {
    var pixels_wrapper = std.ArrayList(PixelTypes.PixelStruct).init(allocator);
    const uncompressed = uncompressed_data;

    var current_filter_method: u8 = 0;
    var height_index: u64 = 0;
    for (0..image_height) |_| {
        var row_index: u64 = 0;
        while (true) {
            const bit_index = height_index * row_size + row_index;

            if (bit_index >= row_size * (height_index + 1)) break;
            if (bit_index >= uncompressed.len) break;
            if (row_index == 0) {
                current_filter_method = uncompressed[bit_index];
                row_index += 1;
                continue;
            }

            if (current_filter_method == 0) { // NO FILTER
                const gray_scale = uncompressed[bit_index];
                const opacity_scale = uncompressed[bit_index + 1];
                const current_pixel = PixelTypes.PixelStruct{ .R = gray_scale, .G = gray_scale, .B = gray_scale, .A = opacity_scale, .COLUMN_INDEX = height_index, .ROW_INDEX = @divTrunc((row_index - 1), 4) };

                try pixels_wrapper.append(current_pixel);
                row_index += 2;
                continue;
            }

            var u16_gray_scale: u16 = uncompressed[bit_index];
            var u16_opacity_scale: u16 = uncompressed[bit_index + 1];

            if (current_filter_method == 1) {
                var previous_gray_scale_bit: u16 = 0;
                var previous_opacity_scale_bit: u16 = 0;

                if (row_index >= 2) {
                    previous_gray_scale_bit = uncompressed[bit_index - 2];
                    previous_opacity_scale_bit = uncompressed[bit_index - 1];
                }

                u16_gray_scale = @intCast(@mod(u16_gray_scale + previous_gray_scale_bit, 256));
                u16_opacity_scale = @intCast(@mod(u16_opacity_scale + previous_opacity_scale_bit, 256));
            } else if (current_filter_method == 2) {
                const row_move_up = height_index * row_size;
                var top_gray_scale_bit: u16 = 0;
                var top_opacity_scale_bit: u16 = 0;

                if (height_index > 0) {
                    top_gray_scale_bit = uncompressed[bit_index - row_move_up];
                    top_opacity_scale_bit = uncompressed[bit_index + 1 - row_move_up];
                }

                u16_gray_scale = @intCast(@mod(u16_gray_scale + top_gray_scale_bit, 256));
                u16_opacity_scale = @intCast(@mod(u16_opacity_scale + top_opacity_scale_bit, 256));
            } else if (current_filter_method == 3) {
                var previous_gray_scale_bit: u16 = 0;
                var previous_opacity_scale_bit: u16 = 0;

                if (row_index >= 2) {
                    previous_gray_scale_bit = uncompressed[bit_index - 2];
                    previous_opacity_scale_bit = uncompressed[bit_index - 1];
                }

                const row_move_up = height_index * row_size;
                var top_gray_scale_bit: u16 = 0;
                var top_opacity_scale_bit: u16 = 0;

                if (height_index > 0) {
                    top_gray_scale_bit = uncompressed[bit_index - row_move_up];
                    top_opacity_scale_bit = uncompressed[bit_index + 1 - row_move_up];
                }

                u16_gray_scale = @intCast(@mod(u16_gray_scale + @divTrunc((top_gray_scale_bit + previous_gray_scale_bit), 2), 256));
                u16_opacity_scale = @intCast(@mod(u16_opacity_scale + @divTrunc((top_opacity_scale_bit + previous_opacity_scale_bit), 2), 256));
            } else if (current_filter_method == 4) {
                var previous_gray_scale_bit: i16 = 0;
                var previous_opacity_scale_bit: i16 = 0;

                if (row_index >= 2) {
                    previous_gray_scale_bit = uncompressed[bit_index - 2];
                    previous_opacity_scale_bit = uncompressed[bit_index - 1];
                }

                const row_move_up = height_index * row_size;
                var top_gray_scale_bit: i16 = 0;
                var top_opacity_scale_bit: i16 = 0;

                if (height_index > 0) {
                    top_gray_scale_bit = uncompressed[bit_index - row_move_up];
                    top_opacity_scale_bit = uncompressed[bit_index + 1 - row_move_up];
                }

                var top_left_gray_scale_bit: i16 = 0;
                var top_left_opacity_scale_bit: i16 = 0;

                if (height_index > 0 and row_index >= 2) {
                    top_left_gray_scale_bit = uncompressed[bit_index - row_move_up - 1];
                    top_left_opacity_scale_bit = uncompressed[bit_index + 1 - row_move_up - 1];
                }

                const gray_scale_bit_p: i16 = previous_gray_scale_bit + top_gray_scale_bit - top_left_gray_scale_bit;
                const gray_scale_bit_a = @abs(gray_scale_bit_p - previous_gray_scale_bit);
                const gray_scale_bit_b = @abs(gray_scale_bit_p - top_gray_scale_bit);
                const gray_scale_bit_c = @abs(gray_scale_bit_p - top_left_gray_scale_bit);
                if (gray_scale_bit_a <= gray_scale_bit_b and gray_scale_bit_a <= gray_scale_bit_c) {
                    u16_gray_scale = @intCast(@mod(u16_gray_scale + gray_scale_bit_a, 256));
                } else if (gray_scale_bit_b <= gray_scale_bit_c) {
                    u16_gray_scale = @intCast(@mod(u16_gray_scale + gray_scale_bit_b, 256));
                } else {
                    u16_gray_scale = @intCast(@mod(u16_gray_scale + gray_scale_bit_c, 256));
                }

                const opacity_scale_bit_p = previous_opacity_scale_bit + top_opacity_scale_bit - top_left_opacity_scale_bit;
                const opacity_scale_bit_a = @abs(opacity_scale_bit_p - previous_opacity_scale_bit);
                const opacity_scale_bit_b = @abs(opacity_scale_bit_p - top_opacity_scale_bit);
                const opacity_scale_bit_c = @abs(opacity_scale_bit_p - top_left_opacity_scale_bit);
                if (opacity_scale_bit_a <= opacity_scale_bit_b and opacity_scale_bit_a <= opacity_scale_bit_c) {
                    u16_opacity_scale = @intCast(@mod(u16_opacity_scale + opacity_scale_bit_a, 256));
                } else if (opacity_scale_bit_b <= opacity_scale_bit_c) {
                    u16_opacity_scale = @intCast(@mod(u16_opacity_scale + opacity_scale_bit_b, 256));
                } else {
                    u16_opacity_scale = @intCast(@mod(u16_opacity_scale + opacity_scale_bit_c, 256));
                }
            }

            const gray_scale: u8 = @intCast(u16_gray_scale);
            const opacity_scale: u8 = @intCast(u16_opacity_scale);

            uncompressed[bit_index] = gray_scale;
            const current_pixel = PixelTypes.PixelStruct{ .R = gray_scale, .G = gray_scale, .B = gray_scale, .A = opacity_scale, .COLUMN_INDEX = height_index, .ROW_INDEX = @divTrunc((row_index - 1), 4) };

            try pixels_wrapper.append(current_pixel);
            row_index += 2;
        }
        height_index += 1;
    }

    return pixels_wrapper;
}
