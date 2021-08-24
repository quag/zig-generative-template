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

const sdf2 = @import("sdf2.zig");

const V2 = @import("affine.zig").V2;
const v2 = V2.init;
const V3 = @import("affine.zig").V3;
const v3 = V3.init;

const gmath = @import("gmath.zig").gmath(f64);
const saturate = gmath.saturate;
const clamp = gmath.clamp;
const mix = gmath.mix;

pub const Sdfn = fn (V3) f64;

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
    pub inline fn origin(p: V3) f64 {
        return p.length();
    }

    pub fn roundFn(comptime sub: Sdfn, comptime r: f64) Sdfn {
        const compiler = struct {
            inline fn round(p: V3) f64 {
                return Dist.round(sub(p), r);
            }
        };
        return compiler.round;
    }

    pub fn displaceFn(comptime f: Sdfn, comptime g: Sdfn) Sdfn {
        const compiler = struct {
            inline fn displace(p: V3) f64 {
                return Dist.displace(f(p), g(p));
            }
        };
        return compiler.displace;
    }

    pub fn sphere01(p: V3) f64 {
        return Dist.round(v3(p.x - 0.5, p.y - 0.5, p.z).length(), 0.5);
    }

    pub fn horizontalExtrudedEllispe(p: V3) f64 {
        const o = v3(0.5, 0.5, 0);
        const round = 0.005;
        const width = 0.8;
        const height = 0.8;
        const curve = 0.2;

        const sp2: V2 = sdf2.NearestPoint.ellipse(v2(p.y - o.y, p.z - o.z), v2(width * 0.5 - round, curve));
        const sp3 = v3(clamp(o.x - height * 0.5 + round, o.x + height * 0.5 - round, p.x), sp2.x + o.y, sp2.y + o.z);
        return p.distTo(sp3) - round;
    }

    pub fn verticalExtrudedEllipse(p: V3) f64 {
        const o = v3(0.5, 0.5, 0);
        const round = 0.005;
        const width = 0.8;
        const height = 0.8;
        const curve = 0.2;

        const sp2: V2 = sdf2.NearestPoint.ellipse(v2(p.x - o.x, p.z - o.z), v2(width * 0.5 - round, curve));
        const sp3 = v3(sp2.x + o.x, clamp(o.y - height * 0.5 + round, o.y + height * 0.5 - round, p.y), sp2.y + o.z);
        return p.distTo(sp3) - round;
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

    pub inline fn displace(a: f64, b: f64) f64 {
        return a + b;
    }
};

pub fn rayMarch(ro: V3, rd: V3, comptime model: Sdfn) ?Marched {
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
    pos: V3,
};

pub fn softShadowMarch(ro: V3, rd: V3, comptime model: Sdfn, k: f64) f64 {
    const stepLimit: usize = 128;
    const closeEnough: f64 = 0.002;
    const maxT: f64 = 1000;

    var t: f64 = 0;
    var step: usize = 0;
    var result: f64 = 1.0;
    while (step < stepLimit and t < maxT) : (step += 1) {
        const pos = rd.scale(t).add(ro);
        const d = model(pos);
        result = math.min(result, k * d / t);
        if (d < closeEnough) {
            return 0;
        }
        t += clamp(0.005, 0.1, d);
    }

    //return math.max(result, 0);
    return 1;
}

//pub fn normal(p: V3, comptime model: Sdfn) V3 {
//    const e = 0.00001;
//    return v3(
//        model(v3(p.x + e, p.y, p.z)) - model(v3(p.x - e, p.y, p.z)),
//        model(v3(p.x, p.y + e, p.z)) - model(v3(p.x, p.y - e, p.z)),
//        model(v3(p.x, p.y, p.z + e)) - model(v3(p.x, p.y, p.z - e)),
//    ).normalize();
//}

//pub fn normal(p: V3, comptime model: Sdfn) V3 {
//    const eps = 0.00001;
//    const x = 0.5773;
//    const y = -0.5773;
//
//    var p1 = v3(x, y, y).scale(model(p.add(v3(x, y, y).scale(eps))));
//    var p2 = v3(y, y, x).scale(model(p.add(v3(y, y, x).scale(eps))));
//    var p3 = v3(y, x, y).scale(model(p.add(v3(y, x, y).scale(eps))));
//    var p4 = v3(x, x, x).scale(model(p.add(v3(x, x, x).scale(eps))));
//
//    return p1.add(p2).add(p3.add(p4)).normalize();
//}

pub fn normal(p: V3, comptime model: Sdfn) V3 {
    const eps = 0.00001;
    const a = 0.5773;
    const b = -0.5773;
    const ae = a * eps;
    const be = b * eps;

    const d1 = model(v3(p.x + ae, p.y + be, p.z + be));
    const d2 = model(v3(p.x + be, p.y + be, p.z + ae));
    const d3 = model(v3(p.x + be, p.y + ae, p.z + be));
    const d4 = model(v3(p.x + ae, p.y + ae, p.z + ae));

    return v3(
        d1 * a + d2 * b + d3 * b + d4 * a,
        d1 * b + d2 * b + d3 * a + d4 * a,
        d1 * b + d2 * a + d3 * b + d4 * a,
    ).normalize();
}
