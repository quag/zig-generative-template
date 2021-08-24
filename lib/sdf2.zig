const std = @import("std");
const math = std.math;

const max = math.max;
const min = math.min;
const abs = math.fabs;
const hypot = math.hypot;
const ln = math.ln;
const exp = math.exp;
const floor = math.floor;
const ceil = math.ceil;

const pi: f64 = math.pi;
const tau: f64 = 6.28318530717958647;
const sqrt3: f64 = 1.73205080756887729;
const invSqrt2: f64 = 0.70710678118654752;

const V2 = @import("affine.zig").V2;
const v2 = V2.init;

const gmath = @import("gmath.zig").gmath(f64);
const saturate = gmath.saturate;
const clamp = gmath.clamp;
const mix = gmath.mix;

pub const Sdfn = fn (V2) f64;

pub const Model = union(enum) {
    const Self = @This();

    Origin: void,
    Round: Round,
    Sdfn: Sdfn,
    Displace: Model2,

    pub fn compile(comptime self: Self) Sdfn {
        return switch (self) {
            .Origin => Sdf.origin,
            .Round => |c| Sdf.roundFn(c.sub.compile(), c.r),
            .Sdfn => |f| f,
            .Displace => |c| Sdf.displaceFn(c.a.compile(), c.b.compile()),
        };
    }
};

pub const Round = struct {
    r: f64,
    sub: *const Model,
};

pub const Model2 = struct {
    a: *const Model,
    b: *const Model,
};

pub const Sdf = struct {
    pub inline fn origin(p: V2) f64 {
        return p.length();
    }

    //pub fn ellipse(p: V2, ab: V2) f64 {
    //    const q = NearestPoint.ellipse(p, ab);
    //    const d = p.distTo(q);
    //    if (p.lengthSq() < q.lengthSq()) {
    //        return -d;
    //    } else {
    //        return d;
    //    }
    //}

    pub fn ellipse(p: V2, ab: V2) f64 {
        const pAbs = p.abs();

        const a = ab.x;
        const b = ab.y;

        const ai = 1 / a;
        const bi = 1 / b;
        const eab = v2((a * a - b * b) * ai, (b * b - a * a) * bi);

        var t = v2(invSqrt2, invSqrt2);

        for ([_]usize{ 0, 1, 2 }) |i| {
            const e = v2(t.x * t.x * t.x, t.y * t.y * t.y).mul(eab);
            const q = pAbs.sub(e);
            const u = q.normalize().scale(t.mul(ab).sub(e).length());
            t = v2(saturate((e.x + u.x) * ai), saturate((e.y + u.y) * bi)).normalize();
        }

        const nearestAbs = t.mul(ab);
        const dist = pAbs.distTo(nearestAbs);
        return if (pAbs.lengthSq() < nearestAbs.lengthSq()) -dist else dist;
    }

    pub fn roundFn(comptime sub: Sdfn, comptime r: f64) Sdfn {
        const compiler = struct {
            inline fn round(p: V2) f64 {
                return Dist.round(sub(p), r);
            }
        };
        return compiler.round;
    }

    pub fn displaceFn(comptime f: Sdfn, comptime g: Sdfn) Sdfn {
        const compiler = struct {
            inline fn displace(p: V2) f64 {
                return Dist.displace(f(p), g(p));
            }
        };
        return compiler.displace;
    }
};

pub const NearestPoint = struct {
    pub fn ellipse(p: V2, ab: V2) V2 {
        const pAbs = p.abs();

        const a = ab.x;
        const b = ab.y;

        const ai = 1 / a;
        const bi = 1 / b;

        const ea = (a * a - b * b) * ai;
        const eb = (b * b - a * a) * bi;

        var t = v2(invSqrt2, invSqrt2);

        for ([_]usize{ 0, 1, 2 }) |i| {
            const e = v2(ea * t.x * t.x * t.x, eb * t.y * t.y * t.y);
            const q = pAbs.sub(e);
            const u = q.normalize().scale(t.mul(ab).sub(e).length());
            t = v2(saturate((e.x + u.x) * ai), saturate((e.y + u.y) * bi)).normalize();
        }

        const nearestAbs = t.mul(ab);
        const nearest = V2{
            .x = math.copysign(f64, nearestAbs.x, p.x),
            .y = math.copysign(f64, nearestAbs.y, p.y),
        };
        return nearest;
    }
};

pub const Sd = struct {
    d: f64,

    const Self = @This();

    pub fn init(d: f64) Self {
        return .{ .d = d };
    }

    pub fn invert(self: Self) Self {
        return init(Dist.invert(self.d));
    }

    pub fn edge(self: Self) Self {
        return init(Dist.edge(self.d));
    }

    pub fn round(self: Self, r: f64) Self {
        return init(Dist.round(self.d, r));
    }

    pub fn annular(self: Self, r: f64) Self {
        return init(Dist.annular(self.d, r));
    }

    pub fn annular2(self: Self, r: f64) Self {
        return init(Dist.annular2(self.d, r));
    }

    pub fn displace(self: Self, other: Self) Self {
        return init(Dist.displace(self.d, other.d));
    }

    pub fn merge(self: Self, other: Self) Self {
        return init(Dist.merge(self.d, other.d));
    }

    pub fn match(self: Self, other: Self) Self {
        return init(Dist.match(self.d, other.d));
    }

    pub fn cut(self: Self, other: Self) Self {
        return init(Dist.cut(self.d, other.d));
    }

    pub fn overlay(self: Self, other: Self) Self {
        return init(Dist.overlay(self.d, other.d));
    }

    pub fn smoothstepC1(self: Self, e0: f64, e1: f64) f64 {
        return gmath.smoothstepC1(e0, e1, self.d);
    }

    pub fn smoothstepC2(self: Self, e0: f64, e1: f64) f64 {
        return gmath.smoothstepC2(e0, e1, self.d);
    }

    pub fn smoothstepC3(self: Self, e0: f64, e1: f64) f64 {
        return gmath.smoothstepC3(e0, e1, self.d);
    }

    pub fn step(self: Self, e: f64) f64 {
        return gmath.step(e, self.d);
    }

    pub fn coStep(self: Self, e: f64) f64 {
        return gmath.coStep(e, self.d);
    }
};

pub const Dist = struct {
    pub inline fn invert(d: f64) f64 {
        return -d;
    }

    pub inline fn edge(d: f64) f64 {
        return abs(d);
    }

    pub inline fn round(d: f64, r: f64) f64 {
        return d - r;
    }

    pub inline fn annular(d: f64, r: f64) f64 {
        return round(edge(d), r);
        //return abs(d) - r;
    }

    pub inline fn annular2(d: f64, r: f64) f64 {
        return annular(annular(d, r + r), r);
        //return round(edge(round(edge(d), r + r)), r);
        //return abs(abs(d) - r - r) - r;
    }

    pub inline fn displace(a: f64, b: f64) f64 {
        return a + b;
    }

    pub inline fn merge(d1: f64, d2: f64) f64 {
        return math.min(d1, d2);
    }

    pub inline fn match(d1: f64, d2: f64) f64 {
        return math.max(d1, d2);
    }

    pub inline fn cut(d1: f64, d2: f64) f64 {
        return match(d1, invert(d2));
    }

    pub inline fn overlay(d1: f64, d2: f64) f64 {
        return if (d1 < 0 and d2 < 0) -math.max(-d2, -d1) else if (d1 < 0) d1 else if (d2 < 0) d2 else math.min(d1, d2);
    }
};

pub fn rayMarch(ro: V2, rd: V2, comptime model: Sdfn) ?Marched {
    const stepLimit: usize = 256;
    const closeEnough: f64 = 0.001;
    const maxT: f64 = 1000;

    var t: f64 = 0;
    var step: usize = 0;
    while (step < stepLimit and t < maxT) : (step += 1) {
        const pos = rd.scale(t).add(ro);
        const d = model(pos);
        if (d < closeEnough) {
            return Marched{
                .d = d,
                .pos = pos,
            };
        }
        t += d * 0.95;
    }

    return null;
}

pub const Marched = struct {
    d: f64,
    pos: V2,
};

pub fn normal(p: V2, comptime model: Sdfn) V2 {
    const e = 0.00001;
    return v2(
        model(v2(p.x + e, p.y)) - model(v2(p.x - e, p.y)),
        model(v2(p.x, p.y + e)) - model(v2(p.x, p.y - e)),
    ).normalize();
}
