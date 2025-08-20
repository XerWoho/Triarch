const std = @import("std");

pub fn random_weight() f32 {
    return random_between_f32(-1, 1); 
}

pub fn random_bias() f32 {
    return random_between_f32(-3, 3); 
}

pub fn random_between_f32(min: f32, max: f32) f32 {
    const rand = std.crypto.random;
    return rand.float(f32) * (max - min) + min;
}

pub fn random_between_i32(min: i32, max: i32) i32 {
    const rand = std.crypto.random;
    return rand.intRangeAtMost(i32, min, max);
}