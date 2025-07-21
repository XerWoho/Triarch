const std = @import("std");
const conversions = @import("../../../lib/conversions.zig");

pub const bKGD = struct {
    sig: 0,
    size: u16,
    crc: u16,

    fn get_sig(self: bKGD) u64 {
        return self.sig;
    }
};

pub const cHRM = struct {
    sig: 0,
    size: u16,
    crc: u16,

    fn get_sig(self: cHRM) u64 {
        return self.sig;
    }
};

pub const cICP = struct {
    sig: 0,
    size: u16,
    crc: u16,

    fn get_sig(self: cICP) u64 {
        return self.sig;
    }
};

pub const dSIG = struct {
    sig: 0,
    size: u16,
    crc: u16,

    fn get_sig(self: dSIG) u64 {
        return self.sig;
    }
};

pub const eXIf = struct {
    sig: 0,
    size: u16,
    crc: u16,

    fn get_sig(self: eXIf) u64 {
        return self.sig;
    }
};

pub const gAMA = struct {
    sig: 1732332865,
    size: u16,
    crc: u16,
    value: u32,
    fn get_real_value(self: gAMA) u64 {
        return self.value * 100000;
    }

    fn get_sig(self: gAMA) u64 {
        return self.sig;
    }
};

pub const hIST = struct {
    sig: 0,
    size: u16,
    crc: u16,

    fn get_sig(self: hIST) u64 {
        return self.sig;
    }
};

pub const iCCP = struct {
    sig: 0,
    size: u16,
    crc: u16,
    fn get_sig(self: iCCP) u64 {
        return self.sig;
    }
};

pub const iTXt = struct {
    sig: 0,
    size: u16,
    crc: u16,
    fn get_sig(self: iTXt) u64 {
        return self.sig;
    }
};

pub const pHYs = struct {
    sig: 1883789683,
    size: u16,
    crc: u16,
    pixels_per_unit_x: u32,
    pixels_per_unit_y: u32,
    unit_specifier: u8,
    fn get_sig(self: pHYs) u64 {
        return self.sig;
    }
};

pub const sBIT = struct {
    sig: 0,
    size: u16,
    crc: u16,
    fn get_sig(self: sBIT) u64 {
        return self.sig;
    }
};

pub const sPLT = struct {
    sig: 0,
    size: u16,
    crc: u16,
    fn get_sig(self: sPLT) u64 {
        return self.sig;
    }
};

pub const sRGB = struct {
    sig: 1934772034,
    size: u16,
    crc: u16,
    rendering_intent: u8,
    fn get_sig(self: sRGB) u64 {
        return self.sig;
    }
};

pub const sTER = struct {
    sig: 0,
    size: u16,
    crc: u16,
    fn get_sig(self: sTER) u64 {
        return self.sig;
    }
};

pub const tEXt = struct {
    sig: 0,
    size: u16,
    crc: u16,
    fn get_sig(self: tEXt) u64 {
        return self.sig;
    }
};

pub const tIME = struct {
    sig: 0,
    size: u16,
    crc: u16,
    fn get_sig(self: tIME) u64 {
        return self.sig;
    }
};

pub const tRNS = struct {
    sig: 0,
    size: u16,
    crc: u16,
    fn get_sig(self: tRNS) u64 {
        return self.sig;
    }
};

pub const zTXt = struct {
    sig: 0,
    size: u16,
    crc: u16,
    fn get_sig(self: zTXt) u64 {
        return self.sig;
    }
};
