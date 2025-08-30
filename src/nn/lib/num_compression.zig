const std = @import("std");

pub fn outputActivation(x: f32) f32 {
    return sigmoid(x);
}

pub fn outputDerivedActivation(x: f32) f32 {
    return sigmoidDerivative(x);
}

pub fn hiddenActivation(x: f32) f32 {
    return sigmoid(x);
}

pub fn hiddenDerivedActivation(x: f32) f32 {
    return sigmoidDerivative(x);
}


fn sigmoid(x: f32) f32 {
    return 1.0 / (1.0 + @exp(-x));
}

fn sigmoidDerivative(x: f32) f32 {
    return sigmoid(x) * (1 - sigmoid(x));
}

// fn tanh(x: f32) f32 {
//     return (@exp(x) - @exp(-x)) / @exp(x) + @exp(-x);
// }

// fn tanhDerivative(x: f32) f32 {
//     return tanh(x) * tanh(x);
// }

// fn relu(x: f32) f32 {
//     return @max(0.0, x);
// }

// fn reluDerivative(x: f32) f32 {
//     if(x >= 0) return 1.0;
//     if(x < 0) return 0.0;
//     return 0.0;
// }

// fn leakyRelu(x: f32) f32 {
//     return @max(0.1 * x, x);
// }

// fn leakyReluDerivative(x: f32) f32 {
//     if(x >= 0) return 1;
//     if(x < 0) return 0.01;
//     return 0.01;
// }

// fn parameticRelu(a: f32, x: f32) f32 {
//     return @max(a * x, x);
// }

// fn parameticReluDerivative(a: f32, x: f32) f32 {
//     if(x >= 0) return 1;
//     if(x < 0) return a;
// }

// fn elu(a: f32 ,x: f32) f32 {
//     if(x >= 0) return x;
//     if(x < 0) return a * (@exp(x) - 1);
// }

// fn eluDerivative(a: f32, x: f32) f32 {
//     if(x >= 0) return 1;
//     if(x < 0) return elu(1, x) + a;
// }


// fn swish(x: f32) f32 {
//     return x * sigmoid(x);
// }

// fn swishDerivative(x: f32) f32 {
//     return swish(x) + sigmoid(x) * (1 - swish(x));
// }
