const std = @import("std");
const PIXEL_TYPE = @import("../../png/types/pixels.zig");

pub fn get_grayscale(gpa: *std.mem.Allocator, pixels: []PIXEL_TYPE.PixelStruct, binary: bool) !std.ArrayList(PIXEL_TYPE.PixelStruct) {
    var copy_pixel = std.ArrayList(PIXEL_TYPE.PixelStruct).init(gpa.*);
    for (0..pixels.len) |i| {
        const pixel = pixels[i];
        const r: f32 = @floatFromInt(pixel.R);
        const g: f32 = @floatFromInt(pixel.G);
        const b: f32 = @floatFromInt(pixel.B);
        const a: f32 = @floatFromInt(pixel.A);

        const r_float_coefficients: f32 = 0.299;
        const g_float_coefficients: f32 = 0.587;
        const b_float_coefficients: f32 = 0.114;

        var brightness = r_float_coefficients * r + g_float_coefficients * g + b_float_coefficients * b;
        brightness = brightness * (a / 255);

        if(binary) {
            if (brightness > 220.5) {
                try copy_pixel.append(PIXEL_TYPE.PixelStruct{
                    .R = 255,
                    .G = 255,
                    .B = 255,
                    .A = 255,
                    .COLUMN_INDEX = pixel.COLUMN_INDEX,
                    .ROW_INDEX = pixel.ROW_INDEX,
                });
            } else {
                try copy_pixel.append(PIXEL_TYPE.PixelStruct{
                    .R = 0,
                    .G = 0,
                    .B = 0,
                    .A = 255,
                    .COLUMN_INDEX = pixel.COLUMN_INDEX,
                    .ROW_INDEX = pixel.ROW_INDEX,
                });
            }
        } else {
            const gray: u8 = @intFromFloat(@min(@max(brightness, 0.0), 255.0));

            // Append grayscale pixel
            try copy_pixel.append(PIXEL_TYPE.PixelStruct{
                .R = gray,
                .G = gray,
                .B = gray,
                .A = 255,
                .COLUMN_INDEX = pixel.COLUMN_INDEX,
                .ROW_INDEX = pixel.ROW_INDEX,
            });
        }
    }

    return copy_pixel;
}
