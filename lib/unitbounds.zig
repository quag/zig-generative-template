const gmath = @import("gmath.zig").gmath(f64);

pub const Pos01 = struct {
    x: f64,
    y: f64,
};

pub const PosI = struct {
    const Self = @This();

    x: isize,
    y: isize,

    pub fn toPosU(self: Self) ?PosU {
        if (self.x >= 0 and self.y >= 0) {
            return PosU{ .x = self.x, .y = self.y };
        } else {
            return null;
        }
    }
};

pub const PosU = struct {
    x: usize,
    y: usize,
};

pub const PosUTo01 = struct {
    const Self = @This();

    xf: gmath.Fma,
    yf: gmath.Fma,

    pub fn forCenter(width: usize, height: usize) Self {
        return init(UnitBoundsF64.init(UnitBounds.initCenter(width, height)));
    }

    pub fn init(ub: UnitBoundsF64) Self {
        return .{
            .xf = gmath.Fma.coMix(ub.x0, ub.x1),
            .yf = gmath.Fma.coMix(ub.y0, ub.y1),
        };
    }

    pub inline fn toPos01(self: Self, x: usize, y: usize) Pos01 {
        return .{
            .x = self.xf.apply(@intToFloat(f64, x)),
            .y = self.yf.apply(@intToFloat(f64, y)),
        };
    }
};

pub const Pos01ToI = struct {
    const Self = @This();

    xf: gmath.Fma,
    yf: gmath.Fma,

    pub fn forCenter(width: usize, height: usize, skew: f64) Self {
        return init(UnitBoundsF64.init(UnitBounds.initCenter(width, height)), skew);
    }

    pub fn init(ub: UnitBoundsF64, skew: f64) Self {
        return .{
            .xf = gmath.Fma.mix(ub.x0 + skew, ub.x1 + skew),
            .yf = gmath.Fma.mix(ub.y0 + skew, ub.y1 + skew),
        };
    }

    pub inline fn toPosI(self: Self, x: f64, y: f64) PosI {
        return .{
            .x = @floatToInt(isize, @floor(self.xf.apply(x))),
            .y = @floatToInt(isize, @floor(self.yf.apply(y))),
        };
    }
};

pub const Pos01ToIndex = struct {
    const Self = @This();

    res: Res,
    ub: Pos01ToI,

    pub fn forCenter(width: usize, height: usize, skew: f64) Self {
        return init(Res.init(width, height), Pos01ToI.forCenter(width, height, skew));
    }

    pub fn init(res: Res, ub: Pos01ToI) Self {
        return .{
            .res = res,
            .ub = ub,
        };
    }

    pub inline fn index(self: Self, x: f64, y: f64) ?usize {
        const pos = self.ub.toPosI(x, y);
        return self.res.indexI(pos.x, pos.y);
    }

    pub inline fn indexOff(self: Self, x: f64, y: f64, xo: isize, yo: isize) ?usize {
        const pos = self.ub.toPosI(x, y);
        return self.res.indexI(pos.x + xo, pos.y + yo);
    }

    pub fn indexOffsets(self: Self, x: f64, y: f64, comptime n: usize, comptime offsets: [n]Offset) [n]?usize {
        const pos = self.ub.toPosI(x, y);
        var result = [_]?usize{null} ** n;
        inline for (offsets) |off, i| {
            result[i] = self.res.indexI(pos.x + off.x, pos.y + off.y);
        }
        return result;
    }

    pub const Offset = struct {
        x: isize,
        y: isize,
    };

    pub const neighbors4 = comptime [4]Offset{
        .{ .x = 0, .y = -1 },
        .{ .x = -1, .y = 0 },
        .{ .x = 1, .y = 0 },
        .{ .x = 0, .y = 1 },
    };

    pub const neighbors5 = comptime [5]Offset{
        .{ .x = 0, .y = -1 },
        .{ .x = -1, .y = 0 },
        .{ .x = 0, .y = 0 },
        .{ .x = 1, .y = 0 },
        .{ .x = 0, .y = 1 },
    };

    pub const neighbors8 = comptime [8]Offset{
        .{ .x = -1, .y = -1 },
        .{ .x = 0, .y = -1 },
        .{ .x = 1, .y = -1 },
        .{ .x = -1, .y = 0 },
        .{ .x = 1, .y = 0 },
        .{ .x = -1, .y = 1 },
        .{ .x = 0, .y = 1 },
        .{ .x = 1, .y = 1 },
    };

    pub const neighbors9 = comptime [9]Offset{
        .{ .x = -1, .y = -1 },
        .{ .x = 0, .y = -1 },
        .{ .x = 1, .y = -1 },
        .{ .x = -1, .y = 0 },
        .{ .x = 0, .y = 0 },
        .{ .x = 1, .y = 0 },
        .{ .x = -1, .y = 1 },
        .{ .x = 0, .y = 1 },
        .{ .x = 1, .y = 1 },
    };
};

pub const Res = struct {
    width: usize,
    height: usize,

    const Self = @This();

    pub fn init(width: usize, height: usize) Self {
        return .{ .width = width, .height = height };
    }

    pub inline fn indexU(self: Self, x: usize, y: usize) ?usize {
        if (xi < self.width and yi < self.height) {
            return y * self.width + x;
        }
        return null;
    }

    pub inline fn indexI(self: Self, x: isize, y: isize) ?usize {
        if (x >= 0 and y >= 0 and x < self.width and y < self.height) {
            const xu = @intCast(usize, x);
            const yu = @intCast(usize, y);
            return yu * self.width + xu;
        }
        return null;
    }
};

pub const UnitBounds = struct {
    const Self = @This();

    x0: usize,
    y0: usize,
    x1: usize,
    y1: usize,

    pub fn initCenter(width: usize, height: usize) Self {
        if (width > height) {
            const unit = height;
            const x0 = (width - unit) / 2;
            return Self{ .x0 = x0, .x1 = x0 + unit, .y0 = 0, .y1 = unit };
        } else {
            const unit = width;
            const y0 = (height - unit) / 2;
            return Self{ .y0 = y0, .y1 = y0 + unit, .x0 = 0, .x1 = unit };
        }
    }
};

pub const UnitBoundsF64 = struct {
    const Self = @This();

    x0: f64,
    y0: f64,
    x1: f64,
    y1: f64,

    pub fn init(ub: UnitBounds) Self {
        return .{
            .x0 = @intToFloat(f64, ub.x0),
            .y0 = @intToFloat(f64, ub.y0),
            .x1 = @intToFloat(f64, ub.x1),
            .y1 = @intToFloat(f64, ub.y1),
        };
    }
};
