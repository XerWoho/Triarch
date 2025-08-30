const std = @import("std");
const conversions = @import("../../../lib/conversions.zig");

pub const AStruct = struct {
    bkgd: bKGD,
    chrm: cHRM,
    cicp: cICP,
    dsig: dSIG,
    exif: eXIf,
    gama: gAMA,
    hist: hIST,
    iccp: iCCP,
    itxt: iTXt,
    phys: pHYs,
    sbit: sBIT,
    splt: sPLT,
    srgb: sRGB,
    ster: sTER,
    text: tEXt,
    time: tIME,
    trns: tRNS,
    ztxt: zTXt
};


pub const bKGD = struct {
    size: u16,
    crc: u16,

    fn get_sig(self: bKGD) u64 {
        return self.sig;
    }
};

pub const cHRM = struct {
    size: u16,
    crc: u16,

    fn get_sig(self: cHRM) u64 {
        return self.sig;
    }
};

pub const cICP = struct {
    size: u16,
    crc: u16,

    fn get_sig(self: cICP) u64 {
        return self.sig;
    }
};

pub const dSIG = struct {
    size: u16,
    crc: u16,

    fn get_sig(self: dSIG) u64 {
        return self.sig;
    }
};



pub const eXIf = struct {
    size: u16,
    crc: u16,

    fn get_sig(self: eXIf) u64 {
        return self.sig;
    }
};

pub const gAMA = struct {
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
    size: u16,
    crc: u16,

    fn get_sig(self: hIST) u64 {
        return self.sig;
    }
};

pub const iCCP = struct {
    size: u16,
    crc: u16,
    fn get_sig(self: iCCP) u64 {
        return self.sig;
    }
};

pub const iTXt = struct {
    size: u16,
    crc: u16,
    fn get_sig(self: iTXt) u64 {
        return self.sig;
    }
};

pub const pHYs = struct {
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
    size: u16,
    crc: u16,
    fn get_sig(self: sBIT) u64 {
        return self.sig;
    }
};

pub const sPLT = struct {
    size: u16,
    crc: u16,
    fn get_sig(self: sPLT) u64 {
        return self.sig;
    }
};

pub const sRGB = struct {
    size: u16,
    crc: u16,
    rendering_intent: u8,
    fn get_sig(self: sRGB) u64 {
        return self.sig;
    }
};

pub const sTER = struct {
    size: u16,
    crc: u16,
    fn get_sig(self: sTER) u64 {
        return self.sig;
    }
};

pub const tEXt = struct {
    size: u16,
    crc: u16,
    fn get_sig(self: tEXt) u64 {
        return self.sig;
    }
};

pub const tIME = struct {
    size: u16,
    crc: u16,
    fn get_sig(self: tIME) u64 {
        return self.sig;
    }
};

pub const tRNS = struct {
    size: u16,
    crc: u16,
    fn get_sig(self: tRNS) u64 {
        return self.sig;
    }
};

pub const zTXt = struct {
    size: u16,
    crc: u16,
    fn get_sig(self: zTXt) u64 {
        return self.sig;
    }
};
