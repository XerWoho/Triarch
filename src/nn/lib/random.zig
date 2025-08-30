const std = @import("std");

pub fn randomWeight() f32 {
    return randomBetweenf32(-1, 1); 
}

pub fn randomBias() f32 {
    return 0.0; // bias' apparently start at 0
    // return random_between_f32(-3, 3); 
}

fn randomBetweenf32(min: f32, max: f32) f32 {
    const rand = std.crypto.random;
    return rand.float(f32) * (max - min) + min;
}

pub fn randomBetweeni32(min: i32, max: i32) i32 {
    const rand = std.crypto.random;
    return rand.intRangeAtMost(i32, min, max);
}