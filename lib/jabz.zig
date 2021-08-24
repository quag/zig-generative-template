const math = @import("std").math;
const fmt = @import("std").fmt;
const gmath = @import("gmath.zig").gmath(f64);

const invSqrt2 = 0.7071067811865475244008443621;
const almostOne = 1.0 - math.f64_epsilon;

pub var srgbHighlightClipping = true;
pub var srgbDesaturateBlacksAndWhites = true;

pub fn Jazbz(comptime T_: type) type {
    return struct {
        const Self = @This();
        pub const AzBz = AzBzType(T_);
        pub const Ch = ChType(T_);

        j: T_ = 0,
        azbz: AzBz = AzBz{},

        pub const black = Self{ .j = 0, .azbz = AzBz.grey };
        pub const white = Self{ .j = almostOne, .azbz = AzBz.grey };

        pub fn init(j: T_, az: T_, bz: T_) Self {
            return Self{
                .j = j,
                .azbz = AzBz{
                    .az = az,
                    .bz = bz,
                },
            };
        }

        pub fn initJch(j: T_, c: T_, h: T_) Self {
            return Self{
                .j = j,
                .azbz = AzBz.initCh(c, h),
            };
        }

        pub fn grey(j: T_) Self {
            return .{ .j = j };
        }

        pub fn scalar(x: T_) Self {
            return Self{ .j = x, .azbz = AzBz.scalar(x) };
        }

        pub fn initSrgb(r: T_, g: T_, b: T_) Self {
            return srgb255ToJzazbz(T_, r * 0xff, g * 0xff, b * 0xff);
        }

        pub fn toSrgb(self: *const Self, comptime Depth: type) Srgb(Depth) {
            if (comptime srgbHighlightClipping) {
                if (self.j < 0) {
                    return Srgb(Depth).initFloat(1, 1, 1);
                } else if (self.j > 1) {
                    return Srgb(Depth).initFloat(0, 0, 0);
                }
            }
            const ab = if (comptime srgbDesaturateBlacksAndWhites) blk: {
                const x = 4.0 * self.j * (1 - self.j);
                const s = gmath.mix(x, math.sqrt(x), x);
                const ab = self.azbz.scale(s);
                break :blk ab;
            } else self.azbz;
            return jzazbzToSrgb(Depth, jTojz(self.j), ab.az, ab.bz);
        }

        pub fn scale(self: *const Self, x: T_) Self {
            return Self{
                .j = self.j * x,
                .azbz = self.azbz.scale(x),
            };
        }

        pub fn scaleJ(self: *const Self, x: T_) Self {
            return Self{
                .j = self.j * x,
                .azbz = self.azbz,
            };
        }

        pub fn desaturate(self: *const Self, x: T_) Self {
            return Self{
                .j = self.j,
                .azbz = self.azbz.scale(x),
            };
        }

        pub fn mixPow(self: *const Self, j0: T_, j1: T_, jp: T_, c0: T_, c1: T_, cp: T_) Self {
            return Self{
                .j = gmath.mixPow(j0, j1, jp, self.j),
                .azbz = self.azbz.mixPow(c0, c1, cp),
            };
        }

        pub fn mix(self: Self, other: Self, alpha: T_) Self {
            return Self{
                .j = gmath.mix(self.j, other.j, alpha),
                .azbz = AzBz.mix(self.azbz, other.azbz, alpha),
            };
        }

        pub fn add(self: *const Self, other: Self) Self {
            return JazbzField.add(self.*, other);
        }

        pub fn mul(self: *const Self, other: Self) Self {
            return JazbzField.mul(self.*, other);
        }

        pub fn complement(self: *const Self) Self {
            return Self{
                .j = 1 - self.j,
                .azbz = self.azbz.rotate180(),
            };
        }

        pub const JazbzField = struct {
            pub const T: type = Self;
            pub const zero: Self = Self{ .j = 0, .azbz = AzBz.AzBzField.zero };
            pub const one: Self = Self{ .j = 1, .azbz = AzBz.AzBzField.one };

            pub fn mul(a: Self, b: Self) Self {
                return Self{
                    .j = a.j * b.j,
                    .azbz = AzBz.AzBzField.mul(a.azbz, b.azbz),
                };
            }

            pub fn add(a: Self, b: Self) Self {
                return Self{
                    .j = a.j + b.j,
                    .azbz = AzBz.AzBzField.add(a.azbz, b.azbz),
                };
            }

            pub fn neg(a: Self) Self {
                return Self{
                    .j = -a.j,
                    .azbz = AzBz.AzBzField.neg(a.azbz),
                };
            }

            pub fn inv(a: Self) Self {
                return Self{
                    .j = 1 / a.j,
                    .azbz = AzBz.AzBzField.inv(a.azbz),
                };
            }
        };

        pub fn addMean(self: *const Self, c: Self) JazbzMean {
            return JazbzMean.fromJazbz(self.*).addMean(c);
        }

        pub const JazbzMean = struct {
            const T = @This();

            n: usize = 0,
            jab: Self = .{},

            pub fn fromJazbz(c: Self) T {
                return .{
                    .n = 1,
                    .jab = c,
                };
            }

            pub fn addMean(self: *T, c: Self) T {
                return self.combine(fromJazbz(c));
            }

            pub fn combine(self: *const T, other: T) T {
                return .{
                    .n = self.n + other.n,
                    .jab = self.jab.add(other.jab),
                };
            }

            pub fn toJazbz(self: *T) Self {
                return self.jab.scale(1 / @intToFloat(f64, math.max(self.n, 1)));
            }
        };

        pub fn addLight(self: *const Self, c: Self) JazbzLight {
            return JazbzLight.fromJazbz(self.*).addLight(c);
        }

        pub fn addWhite(self: *const Self, j: f64) JazbzLight {
            return JazbzLight.fromJazbz(self.*).addWhite(j);
        }

        pub const JazbzLight = struct {
            const T = @This();

            j: T_ = 0,
            az: T_ = 0,
            bz: T_ = 0,

            pub fn fromJazbz(c: Self) T {
                return .{
                    .j = c.j,
                    .az = c.azbz.az * c.j,
                    .bz = c.azbz.bz * c.j,
                };
            }

            pub fn addLight(self: *const T, c: Self) T {
                return self.combine(fromJazbz(c));
            }

            pub fn addWhite(self: *const T, j: f64) T {
                return .{
                    .j = self.j + j,
                    .az = self.az,
                    .bz = self.bz,
                };
            }

            pub fn scaleJ(self: *const T, x: f64) T {
                return .{
                    .j = self.j * x,
                    .az = self.az,
                    .bz = self.bz,
                };
            }

            pub fn combine(self: *const T, jc: T) T {
                return .{
                    .j = self.j + jc.j,
                    .az = self.az + jc.az,
                    .bz = self.bz + jc.bz,
                };
            }

            pub fn toJazbz(self: *const T) Self {
                if (self.j == 0) {
                    return Self.black;
                } else {
                    return .{
                        .j = self.j,
                        .azbz = .{
                            .az = self.az / self.j,
                            .bz = self.bz / self.j,
                        },
                    };
                }
            }
        };
    };
}

fn AzBzType(comptime T_: type) type {
    return struct {
        const Self = @This();
        pub const Ch = ChType(T_);

        az: T_ = 0,
        bz: T_ = 0,

        pub const cm = 0.15934590589262138;
        pub const cmn = cm * invSqrt2;

        pub const grey = Self{ .az = 0, .bz = 0 };

        pub const violet = Self{ .az = 0, .bz = -cm }; // Payne's gray - ink - twilight
        pub const blue = Self{ .az = -cmn, .bz = -cmn }; // cerulean - sky
        pub const teal = Self{ .az = -cm, .bz = 0 }; // viridian - sea
        pub const green = Self{ .az = -cmn, .bz = cmn }; // cadmium green - forest
        pub const yellow = Self{ .az = 0, .bz = cm }; // raw sienna - earth - olive
        pub const red = Self{ .az = cmn, .bz = cmn }; // vermillion - blood
        pub const pink = Self{ .az = cm, .bz = 0 }; // alizarian crimson - rose
        pub const purple = Self{ .az = cmn, .bz = -cmn }; // quinacridone violet

        pub const orange = Self.initCh(1.0, 0.7);

        pub fn initCh(chroma: anytype, hue: anytype) Self {
            const cz = chroma * cm;
            const hz: f64 = hue * 6.28318530717958647 + -3.14159265358979323;
            const az = cz * math.cos(hz);
            const bz = cz * math.sin(hz);
            return Self{ .az = @floatCast(T_, az), .bz = @floatCast(T_, bz) };
        }

        pub fn toCh(self: *const Self) Ch {
            const cz = math.hypot(T_, self.az, self.bz);
            const hz = math.atan2(T_, self.bz, self.az);

            const c = cz * 6.2756554327405890;
            const h = hz * 0.15915494309189535 + 0.5;

            return Ch{
                .c = c,
                .h = h,
            };
        }

        pub fn scalar(x: T_) Self {
            return Self{ .az = x, .bz = x };
        }

        pub fn scale(self: *const Self, x: T_) Self {
            return Self{
                .az = self.az * x,
                .bz = self.bz * x,
            };
        }

        pub fn mixPow(self: *const Self, c0: T_, c1: T_, cp: T_) Self {
            if ((c0 == 0 and c1 == 1 and cp == 1) or (self.az == 0 and self.bz == 0)) {
                return self.*;
            }
            const cz = math.hypot(T_, self.az, self.bz);
            const cz_ = gmath.mixPow(c0, c1, cp, cz);
            return self.scale(cz_ / cz);
        }

        pub fn rotate90(self: *const Self) Self {
            return .{
                .az = -self.bz,
                .bz = self.az,
            };
        }

        pub fn rotate180(self: *const Self) Self {
            return .{
                .az = -self.az,
                .bz = -self.bz,
            };
        }

        pub fn rotate270(self: *const Self) Self {
            return .{
                .az = self.bz,
                .bz = -self.az,
            };
        }

        pub fn rotate(self: *const Self, rx: T_, ry: T_) Self {
            return Self{
                .az = rx * self.az + ry * self.bz,
                .bz = -ry * self.az + rx * self.bz,
            };
        }

        pub fn rotateA(self: *const Self, t: T_) Self {
            return self.rotate(math.cos(t), -math.sin(t));
        }

        pub fn mix(self: Self, other: Self, alpha: T_) Self {
            return Self{
                .az = gmath.mix(self.az, other.az, alpha),
                .bz = gmath.mix(self.bz, other.bz, alpha),
            };
        }

        pub fn add(self: *const Self, other: Self) Self {
            return AzBzField.add(self.*, other);
        }

        pub const AzBzField = struct {
            pub const T: type = Self;
            pub const zero: Self = Self{ .az = 0, .bz = 0 };
            pub const one: Self = Self{ .az = 1, .bz = 1 };

            pub fn mul(x: Self, y: Self) Self {
                return Self{
                    //.az = x.az * y.az + x.bz * y.bz,
                    //.bz = x.az * y.bz + y.bz * x.az,
                    .az = x.az * y.az,
                    .bz = x.bz * y.bz,
                };
            }

            pub fn add(x: Self, y: Self) Self {
                return Self{
                    .az = x.az + y.az,
                    .bz = x.bz + y.bz,
                };
            }

            pub fn neg(x: Self) Self {
                return Self{
                    .az = -x.az,
                    .bz = -x.bz,
                };
            }

            pub fn inv(x: Self) Self {
                const h = 1 / (x.az * x.az + x.bz);
                return Self{
                    //.az = x.az * h,
                    //.bz = -x.bz * h,
                    .az = 1 / x.az,
                    .bz = 1 / x.bz,
                };
            }
        };
    };
}

fn ChType(comptime T: type) type {
    return struct {
        const Self = @This();
        pub const AzBz = AzBzType(T);

        c: T,
        h: T,

        pub fn initCh(chroma: anytype, hue: anytype) Self {
            return Self{ .c = @floatCast(T, chroma), .h = @floatCast(T, hue) };
        }

        pub fn toAzBz(self: *const Self) AzBz {
            return AzBz.initCh(self.c, self.h);
        }
    };
}

pub fn jTojz(j: anytype) @TypeOf(j) {
    return j * 0.16717463120366200 + 1.6295499532821566e-11;
}

pub fn jzToj(j: anytype) @TypeOf(j) {
    return (j - 1.6295499532821566e-11) / 0.16717463120366200;
}

pub fn jzazbzToSrgb(comptime T: type, jz: anytype, az: anytype, bz: anytype) Srgb(T) {
    const iz0 = jz + 1.6295499532821566e-11;
    const iz1 = jz * 0.56 + 0.4400000000091254797;
    const iz = iz0 / iz1;

    const l0 = iz + az * 0.1386050432715393022 + bz * 0.05804731615611882778;
    const m0 = iz + az * -0.1386050432715392744 + bz * -0.05804731615611890411;
    const s0 = iz + az * -0.09601924202631895167 + bz * -0.8118918960560389531;

    const l1 = pow(math.max(l0, 0), 0.007460772656268214777);
    const m1 = pow(math.max(m0, 0), 0.007460772656268214777);
    const s1 = pow(math.max(s0, 0), 0.007460772656268214777);

    const l2 = 0.8359375 - l1;
    const m2 = 0.8359375 - m1;
    const s2 = 0.8359375 - s1;

    const l3 = l1 * 18.6875000 - 18.8515625;
    const m3 = m1 * 18.6875000 - 18.8515625;
    const s3 = s1 * 18.6875000 - 18.8515625;

    const l4 = l2 / l3;
    const m4 = m2 / m3;
    const s4 = s2 / s3;

    const l5 = pow(math.max(l4, 0), 6.277394636015325670);
    const m5 = pow(math.max(m4, 0), 6.277394636015325670);
    const s5 = pow(math.max(s4, 0), 6.277394636015325670);

    const sr0 = l5 * 592.8963755404249891 + m5 * -522.3947425797513470 + s5 * 32.59644233339026778;
    const sg0 = l5 * -222.3295790445721752 + m5 * 382.1527473694614592 + s5 * -57.03433147128811548;
    const sb0 = l5 * 6.270913830078805615 + m5 * -70.21906556220011906 + s5 * 166.6975603243740906;

    const sr1 = sr0 * 12.92;
    const sg1 = sg0 * 12.92;
    const sb1 = sb0 * 12.92;

    const sr2 = pow(math.max(sr0, 0), 0.4166666666666666666);
    const sg2 = pow(math.max(sg0, 0), 0.4166666666666666666);
    const sb2 = pow(math.max(sb0, 0), 0.4166666666666666666);

    const sr3 = sr2 * 1.055 + -0.055;
    const sg3 = sg2 * 1.055 + -0.055;
    const sb3 = sb2 * 1.055 + -0.055;

    const sr = if (sr0 <= 0.003130804953560371341) sr1 else sr3;
    const sg = if (sg0 <= 0.003130804953560371341) sg1 else sg3;
    const sb = if (sb0 <= 0.003130804953560371341) sb1 else sb3;

    return Srgb(T).initFloat(sr, sg, sb);
}

pub fn srgb255ToJzazbz(comptime T: type, sr: anytype, sg: anytype, sb: anytype) Jazbz(T) {
    if (@floatToInt(usize, sr) == 255 and @floatToInt(usize, sg) == 255 and @floatToInt(usize, sb) == 255) {
        return Jazbz(T).white;
    } else if (@floatToInt(usize, sr) == 0 and @floatToInt(usize, sg) == 0 and @floatToInt(usize, sb) == 0) {
        return Jazbz(T).black;
    }

    const r = if (sr <= 10.31475) (sr * 0.0003035269835488375) else pow(sr * 0.003717126661090977 + 0.052132701421800948, 2.4);
    const g = if (sg <= 10.31475) (sg * 0.0003035269835488375) else pow(sg * 0.003717126661090977 + 0.052132701421800948, 2.4);
    const b = if (sb <= 10.31475) (sb * 0.0003035269835488375) else pow(sb * 0.003717126661090977 + 0.052132701421800948, 2.4);

    const l1 = r * 0.003585083359727932572 + g * 0.005092044060011000719 + b * 0.001041169201586239260;
    const m1 = r * 0.002204179837045521148 + g * 0.005922988107728221186 + b * 0.001595495732321790141;
    const s1 = r * 0.0007936150919572405067 + g * 0.002303422557560143382 + b * 0.006631801538878254703;

    const l2 = pow(l1, 0.1593017578125);
    const m2 = pow(m1, 0.1593017578125);
    const s2 = pow(s1, 0.1593017578125);

    const l3 = l2 * 18.8515625 + 0.8359375;
    const m3 = m2 * 18.8515625 + 0.8359375;
    const s3 = s2 * 18.8515625 + 0.8359375;

    const l4 = l2 * 18.6875 + 1;
    const m4 = m2 * 18.6875 + 1;
    const s4 = s2 * 18.6875 + 1;

    const l = pow(l3 / l4, 134.034375);
    const m = pow(m3 / m4, 134.034375);
    const s = pow(s3 / s4, 134.034375);

    const jz0 = l * 0.5 + m * 0.5;
    const jz1 = jz0 * 0.44;
    const jz2 = jz0 * -0.56 + 1;
    const jz3 = jz1 / jz2;

    const jz = jz3 + -1.6295499532821566e-11;

    const az = l * 3.524 + m * -4.066708 + s * 0.542708;
    const bz = l * 0.199076 + m * 1.096799 + s * -1.295875;

    return Jazbz(T){
        .j = math.min(math.max(jzToj(jz), 0.0), 1.0),
        .azbz = Jazbz(T).AzBz{ .az = az, .bz = bz },
    };
}

fn pow(x: anytype, a: anytype) @TypeOf(x + a) {
    const T = @TypeOf(x + a);
    return math.pow(T, x, a);
}

pub fn Srgb(comptime T: type) type {
    return struct {
        const Self = @This();

        r: T,
        g: T,
        b: T,

        pub fn initFloat(r: anytype, g: anytype, b: anytype) Srgb(T) {
            return Srgb(T){
                .r = floatTo(T, r),
                .g = floatTo(T, g),
                .b = floatTo(T, b),
            };
        }

        pub fn toHtmlColor(self: *const Self) ![]u8 {
            var result: [15]u8 = undefined;
            return try fmt.bufPrint(result[0..], "#{x:0<2}{x:0<2}{x:0<2}", @floatToInt(u8, self.r * 0xff), @floatToInt(u8, self.g * 0xff), @floatToInt(u8, self.b * 0xff));
        }
    };
}

pub fn floatTo(comptime T: type, x: anytype) T {
    const y = clamp(0, 1, x);
    if (T == f32 or T == f64) {
        return y;
    } else {
        return @floatToInt(T, y * math.maxInt(T));
    }
}

pub fn clamp(e0: anytype, e1: anytype, x: anytype) @TypeOf(x + e0 + e1) {
    if (x < e0) {
        return e0;
    } else if (x > e1) {
        return e1;
    } else {
        return x;
    }
}
