const std = @import("std");
const math = std.math;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

const sdf2 = @import("sdf2.zig");

const affine = @import("affine.zig");
const V2 = affine.V2;
const v2 = V2.init;

const gmath = @import("gmath.zig").gmath(f64);

pub const Circle = struct {
    pub fn ro(r: f64) Radius {
        return Radius{ .r = r };
    }

    pub fn rp(r: f64, p: V2) PointRadius {
        return PointRadius{ .p = p, .r = r };
    }

    pub fn ppp(a: V2, b: V2, c: V2) ThreePoint {
        return ThreePoint{ .a = a, .b = b, .c = c };
    }

    pub fn ppc(a: V2, b: V2, c: f64) TwoPointCurvature {
        return TwoPointCurvature{ .a = a, .b = b, .c = c };
    }

    // https://en.wikipedia.org/wiki/Circle#Equations
    pub const LineIntersection = union(enum) {
        Intersection: Line.TwoPoints,
        Tangent: V2,
        NoIntersection: void,

        const Self = @This();

        pub fn assumeA(self: Self) V2 {
            return switch (self) {
                .Intersection => |secantLine| secantLine.a,
                .Tangent => |p| p,
                .NoIntersection => V2{},
            };
        }

        pub fn assumeB(self: Self) V2 {
            return switch (self) {
                .Intersection => |secantLine| secantLine.b,
                .Tangent => |p| p,
                .NoIntersection => V2{},
            };
        }
    };

    pub const Radius = struct {
        r: f64,

        const Self = @This();

        pub fn contains(self: *const Self, q: V2) bool {
            return q.lengthSq() <= gmath.sq(self.r);
        }

        pub fn signedDist(self: *const Self, q: V2) sdf2.Sd {
            return sdf2.Sd.init(q.length() - self.r);
        }
    };

    pub const PointRadius = struct {
        p: V2,
        r: f64,

        const Self = @This();

        pub fn contains(self: *const Self, q: V2) bool {
            return ro(self.r).contains(v2(q.x - self.p.x, q.y - self.p.y));
        }

        pub fn signedDist(self: *const Self, q: V2) sdf2.Sd {
            return ro(self.r).signedDist(v2(q.x - self.p.x, q.y - self.p.y));
        }

        pub fn x0(self: *const Self) f64 {
            return self.p.x - self.r;
        }

        pub fn x1(self: *const Self) f64 {
            return self.p.x + self.r;
        }

        pub fn y0(self: *const Self) f64 {
            return self.p.y - self.r;
        }

        pub fn y1(self: *const Self) f64 {
            return self.p.y + self.r;
        }

        pub fn top(self: *const Self) V2 {
            return .{
                .x = self.p.x,
                .y = self.y1(),
            };
        }

        pub fn bot(self: *const Self) V2 {
            return .{
                .x = self.p.x,
                .y = self.y0(),
            };
        }

        pub fn left(self: *const Self) V2 {
            return .{
                .x = self.x0(),
                .y = self.p.y,
            };
        }

        pub fn right(self: *const Self) V2 {
            return .{
                .x = self.x1(),
                .y = self.p.y,
            };
        }

        pub fn intersect(self: *const Self, other: anytype) IntersectType(@TypeOf(other)) {
            return switch (@TypeOf(other)) {
                Line.Vertical => self.intersectLineVertical(other),
                Line.Horizontal => self.intersectLineHorizontal(other),
                Line.TwoPoints => self.intersectLineTwoPoints(other),
                else => @compileError("Unsupported: " ++ @typeName(@TypeOf(other))),
            };
        }

        pub fn IntersectType(comptime other: type) type {
            return switch (other) {
                Line.Vertical => LineIntersection,
                Line.Horizontal => LineIntersection,
                Line.TwoPoints => LineIntersection,
                else => @compileError("Unsupported: " ++ @typeName(other)),
            };
        }

        pub fn intersectLineVertical(self: *const Self, line: Line.Vertical) LineIntersection {
            const tangentx0 = self.p.x - self.r;
            const tangentx1 = self.p.x + self.r;

            if ((line.x < tangentx0) or (line.x > tangentx1)) {
                return .NoIntersection;
            } else if (line.x == tangentx0) {
                return .{ .Tangent = v2(tangentx0, self.p.y) };
            } else if (line.x == tangentx1) {
                return .{ .Tangent = v2(tangentx1, self.p.y) };
            } else {
                const mid = v2(line.x, self.p.y);
                const off = v2(0, math.sqrt(self.r * self.r - (line.x - self.p.x) * (line.x - self.p.x)));
                return .{
                    .Intersection = .{
                        .a = mid.sub(off),
                        .b = mid.add(off),
                    },
                };
            }
        }

        pub fn intersectLineHorizontal(self: *const Self, line: Line.Horizontal) LineIntersection {
            const tangenty0 = self.p.y - self.r;
            const tangenty1 = self.p.y + self.r;

            if ((line.y < tangenty0) or (line.y > tangenty1)) {
                return .NoIntersection;
            } else if (line.y == tangenty0) {
                return .{ .Tangent = v2(tangenty0, self.p.x) };
            } else if (line.y == tangenty1) {
                return .{ .Tangent = v2(tangenty1, self.p.x) };
            } else {
                const mid = v2(self.p.x, line.y);
                const off = v2(math.sqrt(self.r * self.r - (line.y - self.p.y) * (line.y - self.p.y)), 0);
                return .{
                    .Intersection = .{
                        .a = mid.sub(off),
                        .b = mid.add(off),
                    },
                };
            }
        }

        pub fn intersectLineTwoPoints(self: *const Self, line: Line.TwoPoints) LineIntersection {
            if (line.asVertical()) |line2| {
                return self.intersectLineVertical(line2);
            }
            if (line.asHorizontal()) |line2| {
                return self.intersectLineHorizontal(line2);
            }

            // https://mathworld.wolfram.com/Circle-LineIntersection.html

            const a = line.a.sub(self.p);
            const b = line.b.sub(self.p);
            const d = b.sub(a);
            const D = a.x * b.y - b.x * a.y;
            const drdr = d.lengthSq();
            const discriminant = self.r * self.r * drdr - D * D;

            if (discriminant < 0) {
                return .NoIntersection;
            }

            const discriminantSqrt = math.sqrt(discriminant);

            const mid: V2 = .{
                .x = D * d.y,
                .y = -D * d.x,
            };

            const off: V2 = .{
                .x = math.copysign(f64, d.x, d.y) * discriminantSqrt,
                .y = -math.fabs(d.y) * discriminantSqrt,
            };

            const scale = 1.0 / drdr;

            return if (discriminant == 0) .{ .Tangent = mid.add(off).scale(scale).add(self.p) } else .{
                .Intersection = .{
                    .a = mid.sub(off).scale(scale).add(self.p),
                    .b = mid.add(off).scale(scale).add(self.p),
                },
            };
        }
    };

    pub const ThreePoint = struct {
        a: V2,
        b: V2,
        c: V2,

        const Self = @This();
        pub fn asPointRadius(self: *const Self) PointRadius {
            const a = self.a;
            const b = self.b;
            const c = self.c;

            const aby = a.y - b.y;
            const cay = c.y - a.y;
            const bcy = b.y - c.y;

            const adot = a.x * a.x + a.y * a.y;
            const bdot = b.x * b.x + b.y * b.y;
            const cdot = c.x * c.x + c.y * c.y;

            const x = adot * bcy + bdot * cay + cdot * aby;
            const y = adot * (c.x - b.x) + bdot * (a.x - c.x) + cdot * (b.x - a.x);

            const det = 2 * (a.x * bcy + b.x * cay + c.x * aby);

            const o = v2(x / det, y / det);
            return .{ .p = o, .r = math.hypot(f64, a.x - o.x, a.y - o.y) };
        }
    };

    pub const TwoPointCurvature = struct {
        a: V2,
        b: V2,
        c: f64,

        const Self = @This();
        pub fn asPointRadius(self: *const Self) PointRadius {
            // https://stackoverflow.com/questions/36211171/finding-center-of-a-circle-given-two-points-and-radius
            const a = self.a;
            const b = self.b;

            const q = a.distTo(b);
            const minr = q * 0.5;
            const r = minr * (self.c + 1);
            const s = math.sqrt(r * r - minr * minr);

            const ab = a.mix(b, 0.5);

            const p = V2{
                .x = ab.x - s * (b.y - a.y) / q,
                .y = ab.y + s * (b.x - a.x) / q,
            };
            return .{ .p = p, .r = r };
        }
    };
};

pub const Annulus = struct {
    pub fn rro(r0: f64, r1: f64) Radius {
        return Radius{ .r0 = r0, .r1 = r1 };
    }

    pub fn rrp(r0: f64, r1: f64, p: V2) PointRadius {
        return PointRadius{ .p = p, .r0 = r0, .r1 = r1 };
    }

    pub const RadiusRadius = struct {
        r0: f64,
        r1: f64,

        const Self = @This();

        pub fn contains(self: *const Self, q: V2) bool {
            const qls = q.lengthSq();
            return qls >= gmath.sq(self.r0) and qls <= gmath.sq(self.r1);
        }

        pub fn circle0(self: *const Self) Circle.Radius {
            return .{ .r = self.r0 };
        }

        pub fn circle1(self: *const Self) Circle.Radius {
            return .{ .r = self.r1 };
        }
    };

    pub const PointRadiusRadius = struct {
        p: V2,
        r0: f64,
        r1: f64,

        const Self = @This();

        pub fn contains(self: *const Self, q: V2) bool {
            return rro(self.r0, self.r1).contains(v2(q.x - self.p.x, q.y - self.p.y));
        }

        pub fn circle0(self: *const Self) Circle.PointRadius {
            return .{ .r = self.r0, .p = self.p };
        }

        pub fn circle1(self: *const Self) Circle.PointRadius {
            return .{ .r = self.r1, .p = self.p };
        }
    };
};

pub const Line = struct {
    pub fn v(x: f64) Vertical {
        return Vertical{ .x = x };
    }

    pub fn h(y: f64) Horizontal {
        return Horizontal{ .y = y };
    }

    pub fn pp(a: V2, b: V2) TwoPoints {
        return TwoPoints{ .a = a, .b = b };
    }

    pub fn po(p: V2, o: V2) PointOffset {
        return PointOffset{ .p = p, .o = o };
    }

    pub fn pn(p: V2, n: V2) PointNormal {
        return PointNormal{ .p = p, .n = n };
    }

    pub fn my0(m: f64, y0: f64) SlopeIntercept {
        return SlopeIntercept{ .m = m, .y0 = y0 };
    }

    pub fn pm(p: V2, m: f64) PointSlope {
        return PointSlope{ .p = p, .m = m };
    }

    pub fn x0y0(x0: f64, y0: f64) Intercept {
        return Intercept{ .x0 = x0, .y0 = y0 };
    }

    pub const LineIntersection = union(enum) {
        Intersection: V2,
        NoIntersection: void,

        const Self = @This();

        pub fn assume(self: Self) V2 {
            return switch (self) {
                .Intersection => |p| p,
                .NoIntersection => V2{},
            };
        }
    };

    // https://en.wikipedia.org/wiki/Linear_equation#Equation_of_a_line
    pub const Vertical = struct {
        x: f64,

        const Self = @This();

        pub fn signedDist(self: *const Self, q: V2) sdf2.Sd {
            return self.signedDistLeft(q).edge();
        }

        pub fn signedDistLeft(self: *const Self, q: V2) sdf2.Sd {
            return sdf2.Sd.init(q.x - self.x);
        }

        pub fn signedDistRight(self: *const Self, q: V2) sdf2.Sd {
            return sdf2.Sd.init(self.x - q.x);
        }

        pub fn asTwoPoints(self: *const Self) TwoPoints {
            return .{
                .a = .{ .x = self.x, .y = 0 },
                .b = .{ .x = self.x, .y = 1 },
            };
        }

        pub fn intersect(self: *const Self, other: anytype) IntersectType(@TypeOf(other)) {
            return switch (@TypeOf(other)) {
                Line.Vertical => {},
                Line.Horizontal => self.intersectLineHorizontal(other),
                Line.TwoPoints => self.intersectLineTwoPoints(other),
                else => @compileError("Unsupported: " ++ @typeName(@TypeOf(other))),
            };
        }

        pub fn IntersectType(comptime other: type) type {
            return switch (other) {
                Line.Vertical => void,
                Line.Horizontal => V2,
                Line.TwoPoints => LineIntersection,
                else => @compileError("Unsupported: " ++ @typeName(other)),
            };
        }

        pub fn intersectLineHorizontal(self: *const Self, line: Line.Horizontal) V2 {
            return .{ .x = self.x, .y = line.y };
        }

        pub fn intersectLineTwoPoints(self: *const Self, line: Line.TwoPoints) LineIntersection {
            if (line.asVertical()) |line2| {
                return .NoIntersection;
            }

            const a = line.a;
            const b = line.b;

            return .{
                .Intersection = .{
                    .x = self.x,
                    .y = (b.x * a.y - a.x * b.y - self.x * (a.y - b.y)) / (b.x - a.x),
                },
            };
        }
    };

    pub const Horizontal = struct {
        y: f64,

        const Self = @This();

        pub fn signedDist(self: *const Self, q: V2) sdf2.Sd {
            return self.signedDistTop(q).edge();
        }

        pub fn signedDistTop(self: *const Self, q: V2) sdf2.Sd {
            return sdf2.Sd.init(q.y - self.y);
        }

        pub fn signedDistBottom(self: *const Self, q: V2) sdf2.Sd {
            return sdf2.Sd.init(self.y - q.y);
        }

        pub fn asTwoPoints(self: *const Self) TwoPoints {
            return .{
                .a = .{ .x = 0, .y = self.y },
                .b = .{ .x = 1, .y = self.y },
            };
        }

        pub fn intersect(self: *const Self, other: anytype) IntersectType(@TypeOf(other)) {
            return switch (@TypeOf(other)) {
                Line.Vertical => self.intersectLineVertical(other),
                Line.Horizontal => {},
                Line.TwoPoints => self.intersectLineTwoPoints(other),
                else => @compileError("Unsupported: " ++ @typeName(@TypeOf(other))),
            };
        }

        pub fn IntersectType(comptime other: type) type {
            return switch (other) {
                Line.Vertical => V2,
                Line.Horizontal => void,
                Line.TwoPoints => LineIntersection,
                else => @compileError("Unsupported: " ++ @typeName(other)),
            };
        }

        pub fn intersectLineVertical(self: *const Self, line: Line.Vertical) V2 {
            return .{ .x = line.x, .y = self.y };
        }

        pub fn intersectLineTwoPoints(self: *const Self, line: Line.TwoPoints) LineIntersection {
            if (line.asHorizontal()) |line2| {
                return .NoIntersection;
            }

            const a = line.a;
            const b = line.b;

            return .{
                .Intersection = .{
                    .x = (b.y * a.x - a.y * b.x - self.y * (a.x - b.x)) / (b.y - a.y),
                    .y = self.y,
                },
            };
        }
    };

    pub const TwoPoints = struct {
        // all points (x, y) where the follwing is true:
        //   x*(a.y - b.y) + y*(b.x - a.x) + (a.x*b.y - b.x*a.y) == 0
        // Points must be different, otherwise we are describing a point, not a line.
        a: V2,
        b: V2,

        const Self = @This();

        pub fn xxyy(x0: f64, x1: f64, y0: f64, y1: f64) Self {
            return .{
                .a = v2(x0, y0),
                .b = v2(x1, y1),
            };
        }

        pub fn xyxy(x0: f64, y0: f64, x1: f64, y1: f64) Self {
            return .{
                .a = v2(x0, y0),
                .b = v2(x1, y1),
            };
        }

        pub fn asPointOffset(self: *const Self) PointOffset {
            return .{
                .p = self.a,
                .o = self.b.sub(self.a),
            };
        }

        pub fn asPointNormal(self: *const Self) PointNormal {
            return self.asPointOffset().asPointNormal();
        }

        pub fn asVertical(self: *const Self) ?Vertical {
            return if (self.a.x == self.b.x) .{ .x = self.a.x } else null;
        }

        pub fn asHorizontal(self: *const Self) ?Horizontal {
            return if (self.a.y == self.b.y) .{ .y = self.a.y } else null;
        }

        pub fn intersect(self: *const Self, other: anytype) IntersectType(@TypeOf(other)) {
            return switch (@TypeOf(other)) {
                Line.Vertical => other.intersectLineTwoPoints(self.*),
                Line.Horizontal => other.intersectLineTwoPoints(self.*),
                Line.TwoPoints => self.intersectLineTwoPoints(other),
                else => @compileError("Unsupported: " ++ @typeName(@TypeOf(other))),
            };
        }

        pub fn IntersectType(comptime other: type) type {
            return switch (other) {
                Line.Vertical => LineIntersection,
                Line.Horizontal => LineIntersection,
                Line.TwoPoints => LineIntersection,
                else => @compileError("Unsupported: " ++ @typeName(other)),
            };
        }

        pub fn intersectLineTwoPoints(self: *const Self, line: Line.TwoPoints) LineIntersection {
            if (self.asVertical()) |line2| {
                return line2.intersectLineTwoPoints(line);
            }
            if (self.asHorizontal()) |line2| {
                return line2.intersectLineTwoPoints(line);
            }
            if (line.asVertical()) |line2| {
                return line2.intersectLineTwoPoints(self.*);
            }
            if (line.asHorizontal()) |line2| {
                return line2.intersectLineTwoPoints(self.*);
            }

            const x1 = self.a.x;
            const y1 = self.a.y;
            const x2 = self.b.x;
            const y2 = self.b.y;

            const x3 = line.a.x;
            const y3 = line.a.y;
            const x4 = line.b.x;
            const y4 = line.b.y;

            const t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / ((x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4));

            return .{
                .Intersection = .{
                    .x = x1 + t * (x2 - x1),
                    .y = y1 + t * (y2 - y1),
                },
            };
        }

        pub fn point(self: *const Self, t: f64) V2 {
            return V2.mix(self.a, self.b, t);
        }

        pub fn pointOff(self: *const Self, t: f64, u: f64) V2 {
            const n = self.b.sub(self.a).rotate90();
            return V2.mix(self.a, self.b, t).add(n.scale(u));
        }

        pub fn asQuad(self: *const Self) Quad.TwoPoints {
            return .{
                .a = self.a,
                .b = self.b,
            };
        }
    };

    pub const PointOffset = struct {
        p: V2,
        o: V2,

        const Self = @This();

        pub fn asTwoPoints(self: *const Self) TwoPoints {
            return .{
                .a = self.p,
                .b = self.p.add(self.o),
            };
        }

        pub fn asPointNormal(self: *const Self) PointNormal {
            return .{
                .p = self.p,
                .n = self.o.normalize(),
            };
        }

        pub fn asVertical(self: *const Self) ?Vertical {
            return if (self.o.y == 0)
                return .{ .x = self.p.x }
            else
                null;
        }

        pub fn asHorizontal(self: *const Self) ?Horizontal {
            return if (self.o.x == 0) .{ .y = self.p.y } else null;
        }
    };

    pub const PointNormal = struct {
        p: V2,
        n: V2,

        const Self = @This();

        pub fn signedDist(self: *const Self, q: V2) sdf2.Sd {
            return self.signedDistBefore(q).edge();
        }

        pub fn signedDistBefore(self: *const Self, q: V2) sdf2.Sd {
            return sdf2.Sd.init(self.n.y * (q.x - self.p.x) - self.n.x * (q.y - self.p.y));
        }

        pub fn signedDistAfter(self: *const Self, q: V2) sdf2.Sd {
            return sdf2.Sd.init(self.n.x * (q.y - self.p.y) - self.n.y * (q.x - self.p.x));
        }

        pub fn asTwoPoints(self: *const Self) TwoPoints {
            return .{
                .a = self.p,
                .b = self.p.add(self.n),
            };
        }

        pub fn asVertical(self: *const Self) ?Vertical {
            return if (self.n.y == 0) .{ .x = self.p.x } else null;
        }

        pub fn asHorizontal(self: *const Self) ?Horizontal {
            return if (self.n.x == 0) .{ .y = self.p.y } else null;
        }
    };

    pub const SlopeIntercept = struct {
        // No vertical lines, infinite slope.
        m: f64,
        y0: f64,

        const Self = @This();

        pub fn asPointOffset(self: *const Self) PointOffset {
            return .{
                .p = .{ .x = 0, .y = self.y0 },
                .o = .{ .x = 1, .y = self.m },
            };
        }
    };

    pub const PointSlope = struct {
        // No vertical lines, infinite slope.
        p: V2,
        m: f64,

        const Self = @This();

        pub fn asPointOffset(self: *const Self) PointOffset {
            return .{
                .p = self.p,
                .o = .{ .x = 1, .y = self.m },
            };
        }
    };

    pub const Intercept = struct {
        // No horizontal or vertical lines.
        x0: f64, // must not be zero.
        y0: f64, // must not be zero.

        const Self = @This();

        pub fn asTwoPoints(self: *const Self) TwoPoints {
            return .{
                .a = .{ .x = self.x0, .y = 0 },
                .b = .{ .x = 0, .y = self.y0 },
            };
        }
    };
};

pub const Quad = struct {
    pub fn pppp(a: V2, b: V2, c: V2, d: V2) FourPoints {
        return FourPoints{ .a = a, .b = b, .c = c, .d = d };
    }

    pub fn ll(t: Line.TwoPoints, u: Line.TwoPoints) TwoLines {
        return .{ .t = t, .u = u };
    }

    pub fn ps(p: V2, s: V2) PointSize {
        return .{ .p = p, .s = s };
    }

    pub fn pp(a: V2, b: V2) TwoPoints {
        return TwoPoints{ .a = a, .b = b };
    }

    pub const xxyy = TwoPoints.xxyy;
    pub const xyxy = TwoPoints.xyxy;

    pub const FourPoints = struct {
        a: V2,
        b: V2,
        c: V2,
        d: V2,

        const Self = @This();

        pub fn asTwoLines(self: *const Self) TwoLines {
            return .{
                .t = .{ .a = self.a, .b = self.b },
                .u = .{ .a = self.d, .b = self.c },
            };
        }

        pub fn asPointSize(self: *const Self) ?PointSize {
            return if (self.a.x == self.c.x and self.a.y == self.b.y and self.b.x == self.d.x and self.c.y == self.d.y)
                PointSize{
                    .p = self.a,
                    .s = v2(self.b.x - self.a.x, self.c.y - self.a.y),
                }
            else
                null;
        }

        pub fn point(self: *const Self, p: V2) V2 {
            return self.a.mix(self.b, p.x).mix(self.c.mix(self.d, p.x), p.y);
        }

        pub fn mix(self: Self, other: Self, x: f64) Self {
            return .{
                .a = self.a.mix(other.a, x),
                .b = self.b.mix(other.b, x),
                .c = self.c.mix(other.c, x),
                .d = self.d.mix(other.d, x),
            };
        }
    };

    pub const TwoLines = struct {
        t: Line.TwoPoints,
        u: Line.TwoPoints,

        const Self = @This();

        pub fn asFourPoints(self: *const Self) FourPoints {
            return .{
                .a = self.t.a,
                .b = self.t.b,
                .c = self.u.b,
                .d = self.u.a,
            };
        }

        pub fn line(self: *const Self, x: f64) Line.TwoPoints {
            return .{
                .a = self.t.point(x),
                .b = self.u.point(x),
            };
        }

        pub fn quad(self: *const Self, x0: f64, x1: f64) Self {
            return .{ .t = self.line(x0), .u = self.line(x1) };
        }

        pub fn flip(self: *const Self) Self {
            return .{
                .t = .{ .a = self.t.a, .b = self.u.a },
                .u = .{ .a = self.t.b, .b = self.u.b },
            };
        }
    };

    pub const PointSize = struct {
        p: V2,
        s: V2,

        const Self = @This();

        const unit = Self{ .p = V2{ .x = 0, .y = 0 }, .s = V2{ .x = 1, .y = 1 } };

        pub fn asFourPoints(self: *const Self) FourPoints {
            return .{
                .a = self.p,
                .b = v2(self.p.x + self.s.x, self.p.y),
                .c = v2(self.p.x, self.p.y + self.s.y),
                .d = v2(self.p.x + self.s.x, self.p.y + self.s.y),
            };
        }

        pub fn asTwoPoints(self: *const Self) TwoPoints {
            return .{
                .a = self.p,
                .b = v2(self.p.x + self.s.x, self.p.y + self.s.y),
            };
        }
    };

    pub const TwoPoints = struct {
        a: V2,
        b: V2,

        const Self = @This();
        const unit = Self{ .a = V2{ .x = 0, .y = 0 }, .b = V2{ .x = 1, .y = 1 } };

        pub fn xxyy(x0: f64, x1: f64, y0: f64, y1: f64) Self {
            return .{
                .a = v2(x0, y0),
                .b = v2(x1, y1),
            };
        }

        pub fn xyxy(x0: f64, y0: f64, x1: f64, y1: f64) Self {
            return .{
                .a = v2(x0, y0),
                .b = v2(x1, y1),
            };
        }

        pub fn asPointSize(self: *const Self) PointSize {
            return .{
                .p = self.a,
                .s = v2(self.b.x - self.a.x, self.b.y - self.a.y),
            };
        }

        pub fn asFourPoints(self: *const Self) FourPoints {
            return .{
                .a = self.a,
                .b = v2(self.b.x, self.a.y),
                .c = v2(self.a.x, self.b.y),
                .d = self.b,
            };
        }

        pub fn contains(self: *const Self, q: V2) bool {
            return q.x >= self.a.x and q.x <= self.b.x and q.y >= self.a.y and q.y <= self.b.y;
        }

        pub fn asLine(self: *const Self) Line.TwoPoints {
            return .{
                .a = self.a,
                .b = self.b,
            };
        }

        pub fn h(self: *const Self, t: f64) Line.Horizontal {
            return .{ .y = gmath.mix(self.a.y, self.b.y, t) };
        }

        pub fn v(self: *const Self, t: f64) Line.Vertical {
            return .{ .x = gmath.mix(self.a.x, self.b.x, t) };
        }

        pub fn hTop(self: *const Self) Line.Horizontal {
            return .{ .y = self.a.y };
        }

        pub fn hBottom(self: *const Self) Line.Horizontal {
            return .{ .y = self.b.y };
        }

        pub fn vLeft(self: *const Self) Line.Vertical {
            return .{ .x = self.a.x };
        }

        pub fn vRight(self: *const Self) Line.Vertical {
            return .{ .x = self.b.x };
        }

        pub fn ppTop(self: *const Self) Line.TwoPoints {
            return .{
                .a = v2(self.a.x, self.a.y),
                .b = v2(self.b.x, self.a.y),
            };
        }

        pub fn ppBottom(self: *const Self) Line.TwoPoints {
            return .{
                .a = v2(self.a.x, self.b.y),
                .b = v2(self.b.x, self.b.y),
            };
        }

        pub fn ppLeft(self: *const Self) Line.TwoPoints {
            return .{
                .a = v2(self.a.x, self.a.y),
                .b = v2(self.a.x, self.b.y),
            };
        }

        pub fn ppRight(self: *const Self) Line.TwoPoints {
            return .{
                .a = v2(self.b.x, self.a.y),
                .b = v2(self.b.x, self.b.y),
            };
        }

        pub fn bottomLine(self: *const Self) Line.TwoPoints {
            return .{
                .a = v2(self.a.x, self.b.y),
                .b = v2(self.b.x, self.b.y),
            };
        }

        pub fn quad(self: *const Self, q: Self) Self {
            return .{
                .a = v2(gmath.mix(self.a.x, self.b.x, q.a.x), gmath.mix(self.a.y, self.b.y, q.a.y)),
                .b = v2(gmath.mix(self.a.x, self.b.x, q.b.x), gmath.mix(self.a.y, self.b.y, q.b.y)),
            };
        }

        pub fn point(self: *const Self, p: V2) V2 {
            return .{
                .x = gmath.mix(self.a.x, self.b.x, p.x),
                .y = gmath.mix(self.a.y, self.b.y, p.y),
            };
        }

        pub fn split(self: *const Self, other: anytype) SplitType(@TypeOf(other)) {
            return switch (@TypeOf(other)) {
                Line.Vertical => .{
                    .a = Self.xxyy(self.a.x, other.x, self.a.y, self.b.y),
                    .b = Self.xxyy(other.x, self.b.x, self.a.y, self.b.y),
                },
                Line.Horizontal => .{
                    .a = Self.xxyy(self.a.x, self.b.x, self.a.y, other.y),
                    .b = Self.xxyy(self.a.x, self.b.x, other.y, self.b.y),
                },
                //Line.TwoPoints => LineIntersection,
                else => @compileError("Unsupported: " ++ @typeName(other)),
            };
        }

        pub fn splitTopBot(self: *const Self, t: f64) Split(Self, Self) {
            const y = gmath.mix(self.a.y, self.b.y, t);
            return .{
                .a = .{
                    .a = self.a,
                    .b = v2(self.b.x, y),
                },
                .b = .{
                    .a = v2(self.a.x, y),
                    .b = self.b,
                },
            };
        }

        pub fn splitLeftRight(self: *const Self, t: f64) Split(Self, Self) {
            const x = gmath.mix(self.a.x, self.b.x, t);
            return .{
                .a = .{
                    .a = self.a,
                    .b = v2(x, self.b.y),
                },
                .b = .{
                    .a = v2(x, self.a.y),
                    .b = self.b,
                },
            };
        }

        pub fn SplitType(comptime other: type) type {
            return switch (other) {
                Line.Vertical => Split(Self, Self),
                Line.Horizontal => Split(Self, Self),
                //Line.TwoPoints => LineIntersection,
                else => @compileError("Unsupported: " ++ @typeName(other)),
            };
        }

        pub fn asCenterOffset(self: *const Self) CenterOffset {
            const center = self.a.mix(self.b, 0.5);
            return .{
                .c = center,
                .o = self.b.sub(center).abs(),
            };
        }
    };

    pub const CenterOffset = struct {
        c: V2,
        o: V2, // invariants: must be positive and non-zero for both x and y.

        const Self = @This();

        pub fn signedDist(self: *const Self, q: V2) sdf2.Sd {
            const d = q.sub(self.c).abs().sub(self.o);
            const dist = d.max(0).length() + math.min(math.max(d.x, d.y), 0);
            return sdf2.Sd.init(dist);
        }

        pub fn asTwoPoints(self: *const Self) TwoPoints {
            return .{
                .a = self.c.sub(self.o),
                .b = self.c.add(self.o),
            };
        }
    };
};

pub fn Split(comptime A: type, comptime B: type) type {
    return struct { a: A, b: B };
}

test "Vertical asTwoPoints" {
    const v = Line.Vertical{ .x = 2 };
    expectEqual(
        Line.TwoPoints{ .a = .{ .x = 2, .y = 0 }, .b = .{ .x = 2, .y = 1 } },
        v.asTwoPoints(),
    );
}

test "Horizontal asTwoPoints" {
    const h = Line.Horizontal{ .y = 2 };
    expectEqual(
        Line.TwoPoints{ .a = .{ .x = 0, .y = 2 }, .b = .{ .x = 1, .y = 2 } },
        h.asTwoPoints(),
    );
}

test "SlopeIntercept asPointOffset" {
    const si: Line.SlopeIntercept = .{ .m = 2, .y0 = 3 };
    expectEqual(
        Line.PointOffset{ .p = .{ .x = 0, .y = 3 }, .o = .{ .x = 1, .y = 2 } },
        si.asPointOffset(),
    );
}

test "PointSlope asPointOffset" {
    const si: Line.PointSlope = .{ .p = .{ .x = 2, .y = 3 }, .m = 4 };
    expectEqual(
        Line.PointOffset{ .p = .{ .x = 2, .y = 3 }, .o = .{ .x = 1, .y = 4 } },
        si.asPointOffset(),
    );
}

test "intercept asTwoPoints" {
    const si: Line.Intercept = .{ .x0 = 2, .y0 = 3 };
    expectEqual(
        Line.TwoPoints{ .a = .{ .x = 2, .y = 0 }, .b = .{ .x = 0, .y = 3 } },
        si.asTwoPoints(),
    );
}

test "intersect Vertical/Horizontal" {
    const v: Line.Vertical = .{ .x = 2 };
    const h: Line.Horizontal = .{ .y = 3 };
    expectEqual(
        V2{ .x = 2, .y = 3 },
        v.intersect(h),
    );
    expectEqual(
        V2{ .x = 2, .y = 3 },
        h.intersect(v),
    );
}

test "intersect Vertical/TwoPoints horizontal" {
    const v: Line.Vertical = .{ .x = 2 };
    const tp: Line.TwoPoints = .{ .a = .{ .x = 0, .y = 3 }, .b = .{ .x = 1, .y = 3 } };
    expectEqual(
        Line.LineIntersection{ .Intersection = V2{ .x = 2, .y = 3 } },
        v.intersect(tp),
    );
    expectEqual(
        Line.LineIntersection{ .Intersection = V2{ .x = 2, .y = 3 } },
        tp.intersect(v),
    );
}

test "intersect Vertical/TwoPoints vertical" {
    const v: Line.Vertical = .{ .x = 2 };
    const tp: Line.TwoPoints = .{ .a = .{ .x = 3, .y = 0 }, .b = .{ .x = 3, .y = 1 } };
    expectEqual(
        Line.LineIntersection.NoIntersection,
        v.intersect(tp),
    );
    expectEqual(
        Line.LineIntersection.NoIntersection,
        tp.intersect(v),
    );
}

test "intersect Vertical/TwoPoints" {
    const v: Line.Vertical = .{ .x = 2 };
    const tp: Line.TwoPoints = .{ .a = .{ .x = 1, .y = 0 }, .b = .{ .x = 3, .y = 1 } };
    expectEqual(
        Line.LineIntersection{ .Intersection = V2{ .x = 2, .y = 0.5 } },
        v.intersect(tp),
    );
    expectEqual(
        Line.LineIntersection{ .Intersection = V2{ .x = 2, .y = 0.5 } },
        tp.intersect(v),
    );
}

test "intersect Horizontal/TwoPoints horizontal" {
    const h: Line.Horizontal = .{ .y = 2 };
    const tp: Line.TwoPoints = .{ .a = .{ .x = 3, .y = 0 }, .b = .{ .x = 3, .y = 1 } };
    expectEqual(
        Line.LineIntersection{ .Intersection = V2{ .x = 3, .y = 2 } },
        h.intersect(tp),
    );
    expectEqual(
        Line.LineIntersection{ .Intersection = V2{ .x = 3, .y = 2 } },
        tp.intersect(h),
    );
}

test "intersect Horizontal/TwoPoints vertical" {
    const h: Line.Horizontal = .{ .y = 2 };
    const tp: Line.TwoPoints = .{ .a = .{ .x = 0, .y = 3 }, .b = .{ .x = 1, .y = 3 } };
    expectEqual(
        Line.LineIntersection.NoIntersection,
        h.intersect(tp),
    );
    expectEqual(
        Line.LineIntersection.NoIntersection,
        tp.intersect(h),
    );
}

test "intersect Horizontal/TwoPoints" {
    const h: Line.Horizontal = .{ .y = 2 };
    const tp: Line.TwoPoints = .{ .a = .{ .x = 0, .y = 1 }, .b = .{ .x = 1, .y = 3 } };
    expectEqual(
        Line.LineIntersection{ .Intersection = V2{ .x = 0.5, .y = 2 } },
        h.intersect(tp),
    );
    expectEqual(
        Line.LineIntersection{ .Intersection = V2{ .x = 0.5, .y = 2 } },
        tp.intersect(h),
    );
}

test "intersect TwoPoints vertical/TwoPoints horizontal" {
    const h: Line.TwoPoints = (Line.Horizontal{ .y = 2 }).asTwoPoints();
    const v: Line.TwoPoints = (Line.Vertical{ .x = 3 }).asTwoPoints();
    expectEqual(
        Line.LineIntersection{ .Intersection = V2{ .x = 3, .y = 2 } },
        h.intersect(v),
    );
    expectEqual(
        Line.LineIntersection{ .Intersection = V2{ .x = 3, .y = 2 } },
        v.intersect(h),
    );
}

test "intersect TwoPoints/TwoPoints horizontal" {
    const h: Line.TwoPoints = (Line.Horizontal{ .y = 2 }).asTwoPoints();
    const tp: Line.TwoPoints = .{ .a = .{ .x = 0, .y = 1 }, .b = .{ .x = 1, .y = 3 } };
    expectEqual(
        Line.LineIntersection{ .Intersection = V2{ .x = 0.5, .y = 2 } },
        h.intersect(tp),
    );
    expectEqual(
        Line.LineIntersection{ .Intersection = V2{ .x = 0.5, .y = 2 } },
        tp.intersect(h),
    );
}

test "intersect TwoPoints/TwoPoints horizontal" {
    const v: Line.TwoPoints = (Line.Vertical{ .x = 2 }).asTwoPoints();
    const tp: Line.TwoPoints = .{ .a = .{ .x = 1, .y = 0 }, .b = .{ .x = 3, .y = 1 } };
    expectEqual(
        Line.LineIntersection{ .Intersection = V2{ .x = 2, .y = 0.5 } },
        v.intersect(tp),
    );
    expectEqual(
        Line.LineIntersection{ .Intersection = V2{ .x = 2, .y = 0.5 } },
        tp.intersect(v),
    );
}

test "intersect TwoPoints/TwoPoints" {
    const target = V2{ .x = 2, .y = 3 };
    const tp0 = (Line.PointOffset{ .p = target, .o = .{ .x = 1, .y = 2 } }).asTwoPoints();
    const tp1 = (Line.PointOffset{ .p = target, .o = .{ .x = 3, .y = 4 } }).asTwoPoints();
    expectEqual(
        Line.LineIntersection{ .Intersection = target },
        tp0.intersect(tp1),
    );
    expectEqual(
        Line.LineIntersection{ .Intersection = target },
        tp1.intersect(tp0),
    );
}

test "Line.LineIntersection assume" {
    const target = V2{ .x = 2, .y = 3 };
    expectEqual(
        V2{ .x = 0, .y = 0 },
        (Line.LineIntersection.NoIntersection).assume(),
    );
    expectEqual(
        target,
        (Line.LineIntersection{ .Intersection = target }).assume(),
    );
}

test "Circle.LineIntersection assumeA" {
    const target = V2{ .x = 2, .y = 3 };
    expectEqual(
        V2{ .x = 0, .y = 0 },
        (Circle.LineIntersection.NoIntersection).assumeA(),
    );
    expectEqual(
        target,
        (Circle.LineIntersection{ .Tangent = target }).assumeA(),
    );
    expectEqual(
        target,
        (Circle.LineIntersection{ .Intersection = .{ .a = target, .b = V2{} } }).assumeA(),
    );
}

test "Circle.LineIntersection assumeB" {
    const target = V2{ .x = 2, .y = 3 };
    expectEqual(
        V2{ .x = 0, .y = 0 },
        (Circle.LineIntersection.NoIntersection).assumeB(),
    );
    expectEqual(
        target,
        (Circle.LineIntersection{ .Tangent = target }).assumeB(),
    );
    expectEqual(
        target,
        (Circle.LineIntersection{ .Intersection = .{ .a = V2{}, .b = target } }).assumeB(),
    );
}

test "invariant: PointOffset asTwoPoints asPointOffset" {
    const target = Line.PointOffset{ .p = V2{ .x = 2, .y = 3 }, .o = V2{ .x = 4, .y = 5 } };
    expectEqual(
        target,
        target.asTwoPoints().asPointOffset(),
    );
}

test "invariant: TwoPoints asPointOffset asTwoPoints" {
    const target = Line.TwoPoints{ .a = V2{ .x = 2, .y = 3 }, .b = V2{ .x = 4, .y = 5 } };
    expectEqual(
        target,
        target.asPointOffset().asTwoPoints(),
    );
}

test "invariant: Vertical asTwoPoints asVertical" {
    const target = Line.Vertical{ .x = 2 };
    expectEqual(
        target,
        target.asTwoPoints().asVertical() orelse Line.Vertical{ .x = 0 },
    );
}

test "invariant: Horizontal asTwoPoints asHorizontal" {
    const target = Line.Horizontal{ .y = 2 };
    expectEqual(
        target,
        target.asTwoPoints().asHorizontal() orelse Line.Horizontal{ .y = 0 },
    );
}

test "invariant: FourPoints asTwoLines asFourPoints" {
    const target = Quad.FourPoints{ .a = V2{ .x = 1, .y = 2 }, .b = V2{ .x = 3, .y = 4 }, .c = V2{ .x = 5, .y = 6 }, .d = V2{ .x = 7, .y = 8 } };
    expectEqual(
        target,
        target.asTwoLines().asFourPoints(),
    );
}

test "invariant: TwoLines asFourPoints asTwoLines" {
    const target = Quad.TwoLines{ .t = .{ .a = V2{ .x = 1, .y = 2 }, .b = V2{ .x = 3, .y = 4 } }, .u = .{ .a = V2{ .x = 5, .y = 6 }, .b = V2{ .x = 7, .y = 8 } } };
    expectEqual(
        target,
        target.asFourPoints().asTwoLines(),
    );
}

test "invariant: TwoLines flip flip" {
    const target = Quad.TwoLines{ .t = .{ .a = V2{ .x = 1, .y = 2 }, .b = V2{ .x = 3, .y = 4 } }, .u = .{ .a = V2{ .x = 5, .y = 6 }, .b = V2{ .x = 7, .y = 8 } } };
    expectEqual(
        target,
        target.flip().flip(),
    );
}

test "invariant: TwoLines flip quad(0, 1)" {
    const target = Quad.TwoLines{ .t = .{ .a = V2{ .x = 1, .y = 2 }, .b = V2{ .x = 3, .y = 4 } }, .u = .{ .a = V2{ .x = 5, .y = 6 }, .b = V2{ .x = 7, .y = 8 } } };
    expectEqual(
        target,
        target.flip().quad(0, 1),
    );
    expectEqual(
        target,
        target.quad(0, 1).flip(),
    );
    expectEqual(
        target,
        target.quad(1, 0).flip().quad(1, 0).flip(),
    );
}

test "invariant: PointSize asFourPoints asPointSize" {
    const target = Quad.PointSize{ .p = V2{ .x = 1, .y = 2 }, .s = V2{ .x = 3, .y = 4 } };
    expectEqual(
        target,
        target.asFourPoints().asPointSize().?,
    );
}

test "invariant: PointSize asTwoPoints asPointSize" {
    const target = Quad.PointSize{ .p = V2{ .x = 1, .y = 2 }, .s = V2{ .x = 3, .y = 4 } };
    expectEqual(
        target,
        target.asTwoPoints().asPointSize(),
    );
}

test "invariant: Quad.TwoPoints asLine asQuad" {
    const target = Quad.TwoPoints{ .a = V2{ .x = 1, .y = 2 }, .b = V2{ .x = 3, .y = 5 } };
    expectEqual(
        target,
        target.asLine().asQuad(),
    );
}

test "invariant: Line.TwoPoints asQuad asLine" {
    const target = Line.TwoPoints{ .a = V2{ .x = 1, .y = 2 }, .b = V2{ .x = 3, .y = 5 } };
    expectEqual(
        target,
        target.asQuad().asLine(),
    );
}

test "invariant: Quad.TwoPoints inner unit" {
    const target = Quad.TwoPoints{ .a = V2{ .x = 1, .y = 2 }, .b = V2{ .x = 3, .y = 5 } };
    expectEqual(
        target,
        target.inner(Quad.TwoPoints.unit),
    );
}

test "invariant: Line.TwoPoints.xxyy == Line.TwoPoints.xyxy" {
    const x0 = 1;
    const y0 = 2;
    const x1 = 2;
    const y1 = 3;
    expectEqual(
        Line.TwoPoints.xxyy(x0, x1, y0, y1),
        Line.TwoPoints.xyxy(x0, y0, x1, y1),
    );
}

test "invariant: Quad.TwoPoints.xxyy == Quad.TwoPoints.xyxy" {
    const x0 = 1;
    const y0 = 2;
    const x1 = 2;
    const y1 = 3;
    expectEqual(
        Quad.TwoPoints.xxyy(x0, x1, y0, y1),
        Quad.TwoPoints.xyxy(x0, y0, x1, y1),
    );
}
