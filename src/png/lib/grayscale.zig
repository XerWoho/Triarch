const std = @import("std");
const PixelTypes = @import("../../png/types/pixels.zig");
const Constants = @import("../constants.zig");

pub fn getGrayscale(allocator: std.mem.Allocator, pixels: []PixelTypes.PixelStruct, binary: bool) !std.ArrayList(PixelTypes.PixelStruct) {
    var copy_pixel = std.ArrayList(PixelTypes.PixelStruct).init(allocator);
    for (0..pixels.len) |i| {
        const pixel = pixels[i];
        const r: f32 = @floatFromInt(pixel.R);
        const g: f32 = @floatFromInt(pixel.G);
        const b: f32 = @floatFromInt(pixel.B);
        const a: f32 = @floatFromInt(pixel.A);

        var brightness = Constants.R_FLOAT_COEFFICIENTS * r + Constants.G_FLOAT_COEFFICIENTS * g + Constants.B_FLOAT_COEFFICIENTS * b;
        brightness = brightness * (a / 255);

        if(binary) {
            if (brightness > 220.5) {
                try copy_pixel.append(PixelTypes.PixelStruct{
                    .R = Constants.RGB_WHITE,
                    .G = Constants.RGB_WHITE,
                    .B = Constants.RGB_WHITE,
                    .A = 255,
                    .COLUMN_INDEX = pixel.COLUMN_INDEX,
                    .ROW_INDEX = pixel.ROW_INDEX,
                });
            } else {
                try copy_pixel.append(PixelTypes.PixelStruct{
                    .R = Constants.RGB_BLACK,
                    .G = Constants.RGB_BLACK,
                    .B = Constants.RGB_BLACK,
                    .A = 255,
                    .COLUMN_INDEX = pixel.COLUMN_INDEX,
                    .ROW_INDEX = pixel.ROW_INDEX,
                });
            }
        } else {
            const gray: u8 = @intFromFloat(@min(@max(brightness, 0.0), 255.0));

            // Append grayscale pixel
            try copy_pixel.append(PixelTypes.PixelStruct{
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
