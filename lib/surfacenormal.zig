const math = @import("std").math;
const gmath = @import("gmath.zig").gmath(f64);
const sdf2 = @import("sdf2.zig");
const brdf = @import("brdf.zig");
const Jazbz = @import("jabz.zig").Jazbz(f64);

const Circle = @import("geom.zig").Circle;
const Line = @import("geom.zig").Line;
const Quad = @import("geom.zig").Quad;

const V2 = @import("affine.zig").V2;
const V3 = @import("affine.zig").V3;
const v2 = V2.init;
const v3 = V3.init;

const mix = gmath.mix;
const coMix = gmath.coMix;

pub fn shade(object: anytype, preparedMaterial: *const brdf.PreparedMaterial) Jazbz {
    const camera = v3(0.5, 0.5, 512);
    const view = camera.sub(object.surface).normalize();

    const light1 = preparedMaterial.brdf(object.normal, view, v3(0.1, 0.1, 0.5).sub(object.surface).normalize());
    const light2 = preparedMaterial.brdf(object.normal, view, v3(0.8, 0.9, 1).sub(object.surface).normalize());
    //var fill = light1;
    var fill = light1.scaleJ(1).addLight(light2.scaleJ(0.2)).toJazbz();
    fill.j = gmath.filmicDynamicRange(0.01, 0.35 * 1.2, 1, 0.50, fill.j); // filmicDynamicRange(blackPoint, whitePoint, sCurveStrength, sCurveSkew, in)
    fill.azbz = fill.azbz.mixPow(0, 1, 0.94);
    return fill;
}

pub const Sphere = struct {
    const Self = @This();

    blend: sdf2.Sd,
    surface: V3,
    normal: V3,

    pub fn forCircle(c0: Circle.PointRadius, p: V2) ?Self {
        if (circle(c0, p)) |d| {
            const x = p.x - c0.p.x;
            const y = p.y - c0.p.y;
            const r = c0.r;
            const z = math.sqrt(r * r - x * x - y * y);
            return Self{
                .blend = d,
                .surface = v3(p.x, p.y, z),
                .normal = if (z == 0) v3(0, 0, 1) else v3(x / z, y / z, 1).normalize(),
            };
        } else {
            return null;
        }
    }
};

pub const Ellipsoid = struct {
    const Self = @This();

    blend: sdf2.Sd,
    surface: V3,
    normal: V3,

    pub fn forCircle(c0: Circle.PointRadius, depth: f64, p: V2) ?Self {
        if (circle(c0, p)) |d| {
            // surface x*N.i + y*N.j + (c*sqrt(r**2 - y**2 - x**2))*N.k
            // normal (c*x/(sqrt(r**2 - y**2 - x**2)))*N.i + (c*y/(sqrt(r**2 - y**2 - x**2)))*N.j + N.k
            const x = p.x - c0.p.x;
            const y = p.y - c0.p.y;
            const r = c0.r;
            const k = math.sqrt(r * r - y * y - x * x);
            return Self{
                .blend = d,
                .surface = v3(p.x, p.y, depth * k),
                .normal = if (k == 0) v3(0, 0, 1) else v3(x * depth / k, y * depth / k, 1).normalize(),
            };
        } else {
            return null;
        }
    }
};

pub const Torus = struct {
    const Self = @This();

    blend: sdf2.Sd,
    surface: V3,
    normal: V3,

    pub fn forCircle(c0: Circle.PointRadius, r: f64, p: V2) ?Self {
        if (doughnut(Circle.rp(c0.r + r, c0.p), Circle.rp(c0.r - r, c0.p), p)) |d| {
            // surface x*N.i + y*N.j + (sqrt(-R**2 + 2*R*sqrt(x**2 + y**2) + r**2 - x**2 - y**2))*N.k
            // normal (-(R*x/sqrt(x**2 + y**2) - x)/sqrt(-R**2 + 2*R*sqrt(x**2 + y**2) + r**2 - x**2 - y**2))*N.i + (-(R*y/sqrt(x**2 + y**2) - y)/sqrt(-R**2 + 2*R*sqrt(x**2 + y**2) + r**2 - x**2 - y**2))*N.j + N.k
            const x = p.x - c0.p.x;
            const y = p.y - c0.p.y;
            const R = c0.r;
            const a = math.sqrt(x * x + y * y);
            const z = math.sqrt(-R * R + 2 * R * a + r * r - x * x - y * y);
            return Self{
                .blend = d,
                .surface = v3(p.x, p.y, z),
                .normal = if (z == 0 or a == 0) v3(0, 0, 1) else v3(-(R * x / a - x) / z, -(R * y / a - y) / z, 1).normalize(),
            };
        } else {
            return null;
        }
    }
};

pub const EllipticalTorus = struct {
    const Self = @This();

    blend: sdf2.Sd,
    surface: V3,
    normal: V3,

    pub fn forCircle(c0: Circle.PointRadius, r: f64, depth: f64, p: V2) ?Self {
        if (doughnut(Circle.rp(c0.r + r, c0.p), Circle.rp(c0.r - r, c0.p), p)) |d| {
            // surface x*N.i + y*N.j + (depth*sqrt(r**2 - R**2 + 2*R*sqrt(x**2 + y**2) - x**2 - y**2)/r)*N.k
            // normal (-depth*(R*x/sqrt(x**2 + y**2) - x)/(r*sqrt(r**2 - R**2 + 2*R*sqrt(x**2 + y**2) - x**2 - y**2)))*N.i + (-depth*(R*y/sqrt(x**2 + y**2) - y)/(r*sqrt(r**2 - R**2 + 2*R*sqrt(x**2 + y**2) - x**2 - y**2))*N.j + N.k
            const x = p.x - c0.p.x;
            const y = p.y - c0.p.y;
            const R = c0.r;
            const a = math.sqrt(x * x + y * y);
            const b = math.sqrt(r * r - R * R + 2 * R * a - x * x - y * y);
            const z = depth * b / r;
            return Self{
                .blend = d,
                .surface = v3(p.x, p.y, z),
                .normal = if (a == 0 or b == 0) v3(0, 0, 1) else v3(-depth * (R * x / a - x) / (r * b), -depth * (R * y / a - y) / (r * b), 1).normalize(),
            };
        } else {
            return null;
        }
    }
};

pub const SlopedBackground = struct {
    const Self = @This();

    surface: V3,
    normal: V3,

    pub fn forBounds(z0: f64, z1: f64, p: V2) Self {
        // surface x*N.i + y*N.j + (y*z1 + z0*(1 - y))*N.k
        // normal (z0 - z1)*N.j + N.k
        return Self{
            .surface = v3(p.x, p.y, mix(z0, z1, p.y)),
            .normal = v3(0, z0 - z1, 1).normalize(),
        };
    }
};

pub fn doughnut(c0: Circle.PointRadius, c1: Circle.PointRadius, p: V2) ?sdf2.Sd {
    const d0 = c0.signedDist(p);
    const d1 = c1.signedDist(p);
    const d = d0.cut(d1);
    if (d.d <= 0) {
        return d;
    }
    return null;
}

pub fn circle(c0: Circle.PointRadius, p: V2) ?sdf2.Sd {
    const d0 = c0.signedDist(p);
    if (d0.d <= 0) {
        return d0;
    }
    return null;
}
