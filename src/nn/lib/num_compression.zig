const std = @import("std");

pub fn sigmoid(x: f32) f32 {
    return 1.0 / (1.0 + @exp(-x));
}

pub fn sigmoid_derivative(x: f32) f32 {
    return sigmoid(x) * (1 - sigmoid(x));
}


pub fn softplus(x: f32) f32 {
    return @log(1 + @exp(x));
}
