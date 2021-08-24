const std = @import("std");
const math = std.math;
const gmath = @import("gmath.zig");

const invSqrt2: f64 = 0.70710678118654752; // sqrt(2)/2 or 1/sqrt(2)
const halfSqrt3: f64 = 0.86602540378443865; // sqrt(3)/2
const sin_15_degrees: f64 = 0.25881904510252076; // sin(15°) = -sqrt(2)/4 + sqrt(6)/4
const cos_15_degrees: f64 = 0.96592582628906829; // cos(15°) = sqrt(2)/4 + sqrt(6)/4

pub fn NativeField(comptime T_: type) type {
    return struct {
        pub const T = T_;

        pub const zero: T = 0;
        pub const one: T = 1;

        pub fn mul(a: T, b: T) T {
            return a * b;
        }

        pub fn add(a: T, b: T) T {
            return a + b;
        }

        pub fn neg(a: T) T {
            return -a;
        }

        pub fn inv(a: T) T {
            return 1 / a;
        }
    };
}

pub const A1 = Affine1Type(NativeField(f64));
pub const A2 = Affine2Type(NativeField(f64));

pub fn Affine1Type(comptime F: type) type {
    const mul = F.mul;
    const add = F.add;
    const zero = F.zero;
    const one = F.one;
    const neg = F.neg;
    const inv = F.inv;
    return struct {
        const Self = @This();
        const T = F.T;

        m: T,
        a: T,

        pub fn apply(self: *const Self, x: T) T {
            return add(mul(x, self.m), self.a);
        }

        pub const identity = Self{ .m = one, .a = zero };
        pub fn isIdentity(self: *const Self) bool {
            return (self.m == identity.m) and (self.a == identity.a);
        }

        pub fn constant(x: T) Self {
            return Self{ .m = zero, .a = x };
        }

        pub fn add(t: T) Self {
            return Self{ .m = one, .a = t };
        }

        pub fn sub(t: T) Self {
            return Self{ .m = one, .a = neg(t) };
        }

        pub fn scale(s: T) Self {
            return Self{ .m = s, .a = zero };
        }

        pub fn mix(x0: T, x1: T) Self {
            return Self{
                .m = add(x1, neg(x0)),
                .a = x0,
            };
        }

        pub fn coMix(x0: T, x1: T) Self {
            return Self.mix(x0, x1).inverse();
        }

        pub fn map(x0: T, x1: T, y0: T, y1: T) Self {
            return multiply(Self.coMix(x0, x1), Self.mix(y0, y1));
        }

        pub fn compose(x: Self, y: Self) Self {
            return multiply(y, x);
        }

        pub fn multiply(x: Self, y: Self) Self {
            return Self{
                .m = mul(x.m, y.m),
                .a = add(mul(x.a, y.m), y.a),
            };
        }

        pub fn inverse(self: *const Self) Self {
            const m_ = inv(self.m);
            return Self{
                .m = m_,
                .a = neg(mul(self.a, m_)),
            };
        }

        pub fn under(t1: A1, t2: A1) A1 {
            return multiply(t1, multiply(t2, t1.inverse()));
        }
    };
}

fn clamp(comptime T: type, e0: T, e1: T, x: T) T {
    return if (x < e0) e0 else if (x > e1) e1 else x;
}

pub const V2 = struct {
    const Self = @This();

    x: f64 = 0,
    y: f64 = 0,

    pub const zero = comptime Self.init(0, 0);

    pub const cardinalN = comptime Self.init(0, 1);
    pub const cardinalE = comptime Self.init(1, 0);
    pub const cardinalS = comptime Self.init(0, -1);
    pub const cardinalW = comptime Self.init(-1, 0);

    pub const cardinalNE = comptime Self.init(invSqrt2, invSqrt2);
    pub const cardinalSE = comptime Self.init(invSqrt2, -invSqrt2);
    pub const cardinalSW = comptime Self.init(-invSqrt2, -invSqrt2);
    pub const cardinalNW = comptime Self.init(-invSqrt2, invSqrt2);

    // https://en.wikipedia.org/wiki/Angle#Units
    // https://en.wikipedia.org/wiki/Root_of_unity
    pub const degree0 = comptime Self.init(0, 1);
    pub const degree15 = comptime Self.init(sin_15_degrees, cos_15_degrees);
    pub const degree30 = comptime Self.init(0.5, halfSqrt3);
    pub const degree45 = comptime Self.init(invSqrt2, invSqrt2);
    pub const degree60 = comptime Self.init(halfSqrt3, 0.5);
    pub const degree75 = comptime Self.init(cos_15_degrees, sin_15_degrees);
    pub const degree90 = comptime Self.init(1, 0);
    pub const degree105 = comptime Self.init(cos_15_degrees, -sin_15_degrees);
    pub const degree120 = comptime Self.init(halfSqrt3, -0.5);
    pub const degree135 = comptime Self.init(invSqrt2, -invSqrt2);
    pub const degree150 = comptime Self.init(0.5, -halfSqrt3);
    pub const degree165 = comptime Self.init(sin_15_degrees, -cos_15_degrees);
    pub const degree180 = comptime Self.init(0, -1);
    pub const degree195 = comptime Self.init(-sin_15_degrees, -cos_15_degrees);
    pub const degree210 = comptime Self.init(-0.5, -halfSqrt3);
    pub const degree225 = comptime Self.init(-invSqrt2, -invSqrt2);
    pub const degree240 = comptime Self.init(-halfSqrt3, -0.5);
    pub const degree255 = comptime Self.init(-cos_15_degrees, -sin_15_degrees);
    pub const degree270 = comptime Self.init(-1, 0);
    pub const degree285 = comptime Self.init(-cos_15_degrees, sin_15_degrees);
    pub const degree300 = comptime Self.init(-halfSqrt3, 0.5);
    pub const degree315 = comptime Self.init(-invSqrt2, invSqrt2);
    pub const degree330 = comptime Self.init(-0.5, halfSqrt3);
    pub const degree345 = comptime Self.init(-sin_15_degrees, cos_15_degrees);

    pub fn init(x: f64, y: f64) Self {
        return Self{
            .x = x,
            .y = y,
        };
    }

    pub fn angle(t: f64) Self {
        return .{
            .x = math.cos(t),
            .y = -math.sin(t),
        };
    }

    pub fn length(self: Self) f64 {
        return math.hypot(f64, self.x, self.y);
    }

    pub fn lengthSq(self: Self) f64 {
        return self.dot(self);
    }

    pub fn theta(self: Self) f64 {
        return math.atan2(f64, self.y, self.x);
    }

    pub fn abs(self: Self) Self {
        return Self{
            .x = math.fabs(self.x),
            .y = math.fabs(self.y),
        };
    }

    pub fn min(self: Self, low: f64) Self {
        return .{
            .x = math.min(self.x, low),
            .y = math.min(self.y, low),
        };
    }

    pub fn max(self: Self, high: f64) Self {
        return .{
            .x = math.max(self.x, high),
            .y = math.max(self.y, high),
        };
    }

    pub fn clamp(self: Self, low: f64, high: f64) Self {
        return .{
            .x = clamp(low, high, self.x),
            .y = clamp(low, high, self.y),
        };
    }

    pub fn saturate(self: Self, low: f64, high: f64) Self {
        return .{
            .x = saturate(0, 1, self.x),
            .y = saturate(0, 1, self.y),
        };
    }

    pub fn a2(self: Self, t: A2) Self {
        return t.apply(self.x, self.y);
    }

    pub fn toA2(self: Self) Self {
        return A2.add(self.x, self.y);
    }

    pub fn add(self: Self, other: Self) Self {
        return Self{
            .x = self.x + other.x,
            .y = self.y + other.y,
        };
    }

    pub fn mul(self: Self, other: Self) Self {
        return Self{
            .x = self.x * other.x,
            .y = self.y * other.y,
        };
    }

    pub fn neg(self: Self) Self {
        return Self{
            .x = -self.x,
            .y = -self.y,
        };
    }

    pub fn sub(self: Self, other: Self) Self {
        return Self{
            .x = self.x - other.x,
            .y = self.y - other.y,
        };
    }

    pub fn scale(self: Self, m: f64) Self {
        return Self{
            .x = self.x * m,
            .y = self.y * m,
        };
    }

    pub fn fma(self: Self, m: f64, a: f64) Self {
        return Self{
            .x = self.x * m + a,
            .y = self.y * m + a,
        };
    }

    pub fn dot(self: Self, other: Self) f64 {
        return self.x * other.x + self.y * other.y;
    }

    pub fn ndot(self: Self, other: Self) f64 {
        return self.x * other.x - self.y * other.y;
    }

    pub fn normalize(self: Self) Self {
        const len = self.length();
        return if (len == 0) zero else self.scale(1 / len);
    }

    pub fn apply(self: Self, other: Self) f64 {
        return self.x * other.x + self.y * other.y;
    }

    pub fn mix(self: Self, other: Self, alpha: f64) Self {
        const coAlpha = 1 - alpha;
        return .{
            .x = alpha * other.x + coAlpha * self.x,
            .y = alpha * other.y + coAlpha * self.y,
        };
    }

    pub fn coMix(self: Self, other: Self, alpha: f64) Self {
        return .{
            .x = gmath.coMix(a.x, b.x, alpha),
            .y = gmath.coMix(a.y, b.y, alpha),
        };
    }

    pub fn mixV(self: Self, other: Self, alpha: V2) Self {
        return .{
            .x = alpha.x * other.x + (1 - alpha.x) * self.x,
            .y = alpha.y * other.y + (1 - alpha.y) * self.y,
        };
    }

    pub fn rotate(self: Self, rx: f64, ry: f64) Self {
        return .{
            .x = rx * self.x + ry * self.y,
            .y = -ry * self.x + rx * self.y,
        };
    }

    pub fn rotateV(self: Self, r: Self) Self {
        return .{
            .x = r.x * self.x + r.y * self.y,
            .y = -r.y * self.x + r.x * self.y,
        };
    }

    pub fn rotateA(self: Self, t: f64) Self {
        return self.rotate(math.cos(t), -math.sin(t));
    }

    pub fn rotate90(self: Self) Self {
        return .{
            .x = -self.y,
            .y = self.x,
        };
    }

    pub fn rotate180(self: Self) Self {
        return .{
            .x = -self.x,
            .y = -self.y,
        };
    }

    pub fn rotate270(self: Self) Self {
        return .{
            .x = self.y,
            .y = -self.x,
        };
    }

    pub fn project(self: Self, other: Self) Self {
        return self.scale(self.dot(other) / self.dot(self));
    }

    pub fn reject(self: Self, other: Self) Self {
        return other.sub(self.project(other));
    }

    /// https://www.khronos.org/opengles/sdk/docs/manglsl/docbook4/xhtml/reflect.xml
    /// “For a given incident vector I and surface normal N reflect returns the reflection direction calculated as I - 2.0 * dot(N, I) * N.
    /// N should be normalized in order to achieve the desired result.”
    pub fn reflect(normal: Self, incident: Self) Self {
        return incident.sub(normal.scale(2 * normal.dot(incident)));
    }

    pub fn distTo(a: Self, b: Self) f64 {
        return a.sub(b).length();
    }

    pub fn distSqTo(a: Self, b: Self) f64 {
        return a.sub(b).lengthSq();
    }

    pub fn transpose(self: Self) Self {
        return .{
            .x = self.y,
            .y = self.x,
        };
    }

    pub fn quantize(self: Self, quantum: Self) Self {
        return .{
            .x = @trunc(self.x / quantum.x) * quantum.x,
            .y = @trunc(self.y / quantum.y) * quantum.y,
        };
    }

    pub fn fract(self: Self) Self {
        return .{
            .x = @mod(self.x, 1),
            .y = @mod(self.y, 1),
        };
    }

    pub fn floor(self: Self) Self {
        return .{
            .x = math.floor(self.x),
            .y = math.floor(self.y),
        };
    }

    pub fn inverse(self: Self) Self {
        return .{
            .x = 1.0 / self.x,
            .y = 1.0 / self.y,
        };
    }

    pub fn inHalfN(self: Self) bool {
        return self.y < 0.5;
    }

    pub fn inHalfS(self: Self) bool {
        return self.y >= 0.5;
    }

    pub fn inHalfW(self: Self) bool {
        return self.x < 0.5;
    }

    pub fn inHalfE(self: Self) bool {
        return self.x >= 0.5;
    }

    pub fn inHalfNW(self: Self) bool {
        return self.x + self.y < 1;
    }

    pub fn inHalfSE(self: Self) bool {
        return self.x + self.y >= 1;
    }

    pub fn inHalfNE(self: Self) bool {
        return self.x >= self.y;
    }

    pub fn inHalfSW(self: Self) bool {
        return self.x < self.y;
    }

    pub fn checkerboard(self: Self) bool {
        return @floatToInt(i32, self.x) & 1 == @floatToInt(i32, self.y) & 1;
    }
};

pub const V3 = struct {
    const Self = @This();

    x: f64 = 0,
    y: f64 = 0,
    z: f64 = 0,

    pub const zero = Self{ .x = 0, .y = 0, .z = 0 };

    pub fn init(x: f64, y: f64, z: f64) Self {
        return .{
            .x = x,
            .y = y,
            .z = z,
        };
    }

    pub fn dot(a: Self, b: Self) f64 {
        return a.x * b.x + a.y * b.y + a.z * b.z;
    }

    pub fn lengthSq(self: Self) f64 {
        return dot(self, self);
    }

    pub fn length(self: Self) f64 {
        return math.sqrt(lengthSq(self));
    }

    pub fn abs(self: Self) Self {
        return .{
            .x = math.fabs(self.x),
            .y = math.fabs(self.y),
            .z = math.fabs(self.z),
        };
    }

    pub fn min(self: Self, low: f64) Self {
        return .{
            .x = math.min(self.x, low),
            .y = math.min(self.y, low),
            .z = math.min(self.z, low),
        };
    }

    pub fn max(self: Self, high: f64) Self {
        return .{
            .x = math.max(self.x, high),
            .y = math.max(self.y, high),
            .z = math.max(self.z, high),
        };
    }

    pub fn clamp(self: Self, low: f64, high: f64) Self {
        return .{
            .x = clamp(low, high, self.x),
            .y = clamp(low, high, self.y),
            .z = clamp(low, high, self.z),
        };
    }

    pub fn saturate(self: Self, low: f64, high: f64) Self {
        return .{
            .x = saturate(0, 1, self.x),
            .y = saturate(0, 1, self.y),
            .z = saturate(0, 1, self.z),
        };
    }

    pub fn add(a: Self, b: Self) Self {
        return .{
            .x = a.x + b.x,
            .y = a.y + b.y,
            .z = a.z + b.z,
        };
    }

    pub fn sub(a: Self, b: Self) Self {
        return .{
            .x = a.x - b.x,
            .y = a.y - b.y,
            .z = a.z - b.z,
        };
    }

    pub fn mul(a: Self, b: Self) Self {
        return .{
            .x = a.x * b.x,
            .y = a.y * b.y,
            .z = a.z * b.z,
        };
    }

    pub fn neg(self: Self) Self {
        return .{
            .x = -self.x,
            .y = -self.y,
            .z = -self.z,
        };
    }

    pub fn scale(self: Self, m: f64) Self {
        return .{
            .x = self.x * m,
            .y = self.y * m,
            .z = self.z * m,
        };
    }

    pub fn fma(self: Self, m: f64, a: f64) Self {
        return .{
            .x = self.x * m + a,
            .y = self.y * m + a,
            .z = self.z * m + a,
        };
    }

    pub fn normalize(self: Self) Self {
        const mag = self.length();
        return if (mag == 0) zero else self.scale(1 / mag);
    }

    pub fn mix(a: Self, b: Self, alpha: f64) Self {
        const coAlpha = 1 - alpha;
        return .{
            .x = a.x * alpha + b.x * coAlpha,
            .y = a.y * alpha + b.y * coAlpha,
            .z = a.z * alpha + b.z * coAlpha,
        };
    }

    pub fn mixV(a: Self, b: Self, alpha: Self) Self {
        return .{
            .x = a.x * alpha.x + b.x * (1 - alpha.x),
            .y = a.y * alpha.y + b.y * (1 - alpha.y),
            .z = a.z * alpha.z + b.z * (1 - alpha.z),
        };
    }

    /// Scalar projection of a onto b.
    pub fn scalarProjection(a: Self, b: Self) Self {
        const lenb = b.length();
        return if (lenb == 0) 0 else a.dot(b) / lenb;
    }

    /// Vector projection of a onto b.
    pub fn vectorProjection(a: Self, b: Self) Self {
        const bdotb = b.dot(b);
        return if (bdotb == 0) zero else b.scale(a.dot(b) / bdotb);
    }

    /// Vector rejection of a from b.
    pub fn vectorRejection(a: Self, b: Self) Self {
        return a.sub(vectorProjection(a, b));
    }

    pub fn distTo(a: Self, b: Self) f64 {
        return a.sub(b).length();
    }

    /// https://www.khronos.org/opengles/sdk/docs/manglsl/docbook4/xhtml/reflect.xml
    /// “For a given incident vector I and surface normal N reflect returns the reflection direction calculated as I - 2.0 * dot(N, I) * N.
    /// N should be normalized in order to achieve the desired result.”
    pub fn reflect(normal: Self, incident: Self) Self {
        return incident.sub(normal.scale(2 * normal.dot(incident)));
    }

    pub fn cross(a: Self, b: Self) Self {
        return .{
            .x = a.y * b.z - b.y * a.z,
            .y = a.z * b.x - b.z * a.x,
            .z = a.x * b.y - b.x * a.y,
        };
    }
};

pub const MeanV1 = struct {
    const Self = @This();

    n: u64 = 0,
    x: f64 = 0,

    fn add(self: *Self, x: f64) void {
        self.n += 1;
        self.x += x;
    }

    fn merge(self: *Self, other: *const Self) void {
        self.n += other.n;
        self.x += other.x;
    }

    fn toMean(self: *const Self) ?f64 {
        if (self.n == 0) {
            return null;
        }
        return self.x / @intToFloat(f64, self.n);
    }
};

pub const MeanV2 = struct {
    const Self = @This();

    n: u64 = 0,
    x: f64 = 0,
    y: f64 = 0,

    fn add(self: *Self, sample: V2) void {
        self.n += 1;
        self.x += sample.x;
        self.y += sample.y;
    }

    fn merge(self: *Self, other: *const Self) void {
        self.n += other.n;
        self.x += other.x;
        self.y += other.y;
    }

    fn toMean(self: *const Self) ?V2 {
        if (self.n == 0) {
            return null;
        }
        const n = 1 / @intToFloat(f64, self.n);
        return V2{
            .x = self.x * n,
            .y = self.y * n,
        };
    }
};

pub fn Affine2Type(comptime F: type) type {
    const mul = F.mul;
    const add = F.add;
    const zero = F.zero;
    const one = F.one;
    const neg = F.neg;
    const inv = F.inv;
    return struct {
        const Self = @This();
        const T = F.T;

        a: T,
        b: T,
        c: T,
        d: T,
        e: T,
        f: T,

        pub fn apply(self: *const Self, x: T, y: T) V2 {
            return V2{
                .x = self.applyX(x, y),
                .y = self.applyY(x, y),
            };
        }

        pub fn applyV(self: *const Self, p: V2) V2 {
            return V2{
                .x = add(add(mul(self.a, p.x), mul(self.b, p.y)), self.c),
                .y = add(add(mul(self.d, p.x), mul(self.e, p.y)), self.f),
            };
        }

        pub fn applyX(self: *const Self, x: T, y: T) T {
            return add(add(mul(self.a, x), mul(self.b, y)), self.c);
        }

        pub fn applyY(self: *const Self, x: T, y: T) T {
            return add(add(mul(self.d, x), mul(self.e, y)), self.f);
        }

        pub fn applyVX(self: *const Self, p: V2) T {
            return add(add(mul(self.a, p.x), mul(self.b, p.y)), self.c);
        }

        pub fn applyVY(self: *const Self, p: V2) T {
            return add(add(mul(self.d, p.x), mul(self.e, p.y)), self.f);
        }

        pub fn applyLinearV(self: *const Self, p: V2) V2 {
            return V2{
                .x = add(mul(self.a, p.x), mul(self.b, p.y)),
                .y = add(mul(self.d, p.x), mul(self.e, p.y)),
            };
        }

        pub const identity = Self{ .a = one, .b = zero, .c = zero, .d = zero, .e = one, .f = zero };
        pub fn isIdentity(self: *const Self) bool {
            return (self.a == identity.a) and (self.b == identity.b) and (self.c == identity.c) and (self.d == identity.d) and (self.e == identity.e) and (self.f == identity.f);
        }

        pub fn constant(tx: T, ty: T) Self {
            return Self{ .a = zero, .b = zero, .c = tx, .d = zero, .e = zero, .f = ty };
        }

        pub fn add(tx: T, ty: T) Self {
            return Self{ .a = one, .b = zero, .c = tx, .d = zero, .e = one, .f = ty };
        }

        pub fn sub(tx: T, ty: T) Self {
            return Self.add(neg(tx), neg(ty));
        }

        pub fn scale(sx: T, sy: T) Self {
            return Self{ .a = sx, .b = zero, .c = zero, .d = zero, .e = sy, .f = zero };
        }

        pub fn shear2(kx: T, ky: T) Self {
            return Self.shear4(one, ky, kx, one);
        }

        pub fn shear4(kxx: T, kxy: T, kyx: T, kyy: T) Self {
            return Self{ .a = kxx, .b = kyx, .c = zero, .d = kxy, .e = kyy, .f = zero };
        }

        pub fn rotate(rx: T, ry: T) Self {
            return Self{ .a = rx, .b = ry, .c = zero, .d = neg(ry), .e = rx, .f = zero };
        }

        pub fn rotateV(r: V2) Self {
            return Self.rotate(r.x, r.y);
        }

        pub fn rotate90() Self {
            return Self.rotate(zero, neg(one));
        }

        pub fn rotate180() Self {
            return Self.rotate(neg(one), zero);
        }

        pub fn rotate270() Self {
            return Self.rotate(zero, one);
        }

        pub fn multiply(x: Self, y: Self) Self {
            return Self{
                .a = add(mul(x.a, y.a), mul(x.b, y.d)),
                .b = add(mul(x.a, y.b), mul(x.b, y.e)),
                .c = add(add(mul(x.a, y.c), mul(x.b, y.f)), x.c),
                .d = add(mul(x.d, y.a), mul(x.e, y.d)),
                .e = add(mul(x.d, y.b), mul(x.e, y.e)),
                .f = add(add(mul(x.d, y.c), mul(x.e, y.f)), x.f),
            };
        }

        pub fn compose(x: Self, y: Self) Self {
            return multiply(y, x);
        }

        pub fn sum(x: Self, y: Self) Self {
            return Self{
                .a = x.a + y.a,
                .b = x.b + y.b,
                .c = x.c + y.c,
                .d = x.d + y.d,
                .e = x.e + y.e,
                .f = x.f + y.f,
            };
        }

        //pub fn chain(args: ...) Self {
        //    var result = Self.identity;
        //    comptime var i = 0;
        //    inline while (i < args.len) : (i += 1) {
        //        result = multiply(args[i], result);
        //    }
        //    return result;
        //}

        pub fn mix(x0: T, x1: T, y0: T, y1: T) Self {
            return multiply(Self.add(x0, y0), Self.scale(add(x1, neg(x0)), add(y1, neg(y0))));
        }

        pub fn coMix(x0: T, x1: T, y0: T, y1: T) Self {
            return Self.mix(x0, x1, y0, y1).inverse();
        }

        pub fn map(x0: T, x1: T, x2: T, x3: T, y0: T, y1: T, y2: T, y3: T) Self {
            return multiply(Self.coMix(x0, x1, y0, y1), Self.mix(x2, x3, y2, y3));
        }

        // https://en.wikipedia.org/wiki/Invertible_matrix#Methods_of_matrix_inversion
        pub fn inverse(self: *const Self) Self {
            const det = inv(add(mul(self.a, self.e), neg(mul(self.b, self.d))));

            return Self{
                .a = mul(det, self.e),
                .b = neg(mul(det, self.b)),
                .c = mul(det, add(mul(self.b, self.f), neg(mul(self.c, self.e)))),
                .d = neg(mul(det, self.d)),
                .e = mul(det, self.a),
                .f = neg(mul(det, add(mul(self.a, self.f), neg(mul(self.c, self.d))))),
            };
        }

        pub fn under(t1: A2, t2: A2) A2 {
            return multiply(t1.inverse(), multiply(t2, t1));
        }
    };
}

pub const MeanA1 = struct {
    const Self = @This();

    n: u64,
    m: f64,
    a: f64,

    pub fn init() Self {
        return Self{
            .n = 0,
            .m = 0,
            .a = 0,
        };
    }

    pub fn add(self: *Self, sample: A1) void {
        self.n += 1;
        self.m += sample.m;
        self.a += sample.a;
    }

    pub fn merge(self: *Self, other: *const Self) void {
        self.n += other.n;
        self.m += other.m;
        self.a += other.a;
    }

    pub fn toA1(self: *const Self) ?A1 {
        if (self.n == 0) {
            return null;
        }
        const n = 1 / @intToFloat(self.n);
        return A1{
            .m = self.m * n,
            .a = self.a * n,
        };
    }
};

pub const MeanA2 = struct {
    const Self = @This();

    n: u64,
    a: f64,
    b: f64,
    c: f64,
    d: f64,
    e: f64,
    f: f64,

    pub fn init() Self {
        return Self{
            .n = 0,
            .a = 0,
            .b = 0,
            .c = 0,
            .d = 0,
            .e = 0,
            .f = 0,
        };
    }

    pub fn add(self: *Self, sample: A2) void {
        self.n += 1;
        self.a += sample.a;
        self.b += sample.b;
        self.c += sample.c;
        self.d += sample.d;
        self.e += sample.e;
        self.f += sample.f;
    }

    pub fn merge(self: *Self, other: *const Self) void {
        self.n += other.n;
        self.a += other.a;
        self.b += other.b;
        self.c += other.c;
        self.d += other.d;
        self.e += other.e;
        self.f += other.f;
    }

    pub fn toA2(self: *const Self) ?A2 {
        if (self.n == 0) {
            return null;
        }
        const n = 1 / @intToFloat(self.n);
        return A2{
            .a = self.a * n,
            .b = self.b * n,
            .c = self.c * n,
            .d = self.d * n,
            .e = self.e * n,
            .f = self.f * n,
        };
    }
};
