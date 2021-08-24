const math = @import("std").math;
const gmath = @import("gmath.zig").gmath(f64);

const Jazbz = @import("jabz.zig").Jazbz(f64);
const AzBz = Jazbz.AzBz;
const colors = @import("colors.zig").Colors(Jazbz);

const GridSize = @import("gridsize.zig").GridSize;
const V2 = @import("affine.zig").V2;
const v2 = @import("affine.zig").V2.init;
const mix = gmath.mix;
const coMix = gmath.coMix;

pub fn CheckedBackground(comptime count: usize) type {
    const fore = colors.steelBlue;
    const dark = mix(fore, colors.black, 0.3);
    const light = mix(fore, colors.white, 0.3);

    const tileCount: f64 = @intToFloat(f64, count);
    const tiles = v2(tileCount, tileCount);
    const u = tiles.inverse();
    const uh = u.scale(0.5);
    const smooth = 0.001;

    return struct {
        pub fn content(baseJab: Jazbz, x: f64, y: f64) Jazbz {
            const p = v2(x, y);
            var c0 = light;
            var c1 = dark;
            const i = p.mul(tiles).floor();
            const xi = @floatToInt(isize, i.x) + @as(isize, if (i.x < 0) 1 else 0);
            const yi = @floatToInt(isize, i.y) + @as(isize, if (i.y < 0) 1 else 0);

            if (xi & 1 == yi & 1) {
                c0 = dark;
                c1 = light;
            }

            const d = p.sub(p.quantize(u));
            const sy = gmath.smoothstepC3(-smooth, smooth, if (d.y > uh.y) u.y - d.y else d.y);
            const sx = gmath.smoothstepC3(-smooth, smooth, if (d.x > uh.x) u.x - d.x else d.x);
            return mix(c0, c1, sx + sy - 2 * sx * sy);
        }
    };
}

pub const OverlayGrid = struct {
    const Self = @This();
    tiles: V2 = .{ .x = 12, .y = 12 },
    origin: V2 = .{ .x = 0, .y = 0 },
    stroke: f64 = 0.006,
    outline: Jazbz = Jazbz.grey(0.5),
    highlight: Jazbz = Jazbz{ .j = 0.8, .azbz = AzBz.green },

    pub fn compile(comptime self: *const Self) type {
        const d = self.tiles.inverse();
        const halfStroke = self.stroke * 0.5;

        const pp = self.highlight;
        const np = Jazbz{ .j = self.highlight.j, .azbz = self.highlight.azbz.rotate90() };
        const pn = Jazbz{ .j = self.highlight.j, .azbz = self.highlight.azbz.rotate270() };
        const nn = Jazbz{ .j = self.highlight.j, .azbz = self.highlight.azbz.rotate180() };
        return struct {
            pub fn content(baseJab: Jazbz, x: f64, y: f64) Jazbz {
                const p = v2(x, y).sub(self.origin);
                const q = p.quantize(d);
                const edgeDist = math.min(math.min(math.fabs(p.x - q.x), math.fabs(p.y - q.y)), math.min(math.fabs(q.x + d.x - p.x), math.fabs(q.y + d.y - p.y)));

                var jab = baseJab;
                jab = mix(self.outline, jab, gmath.smoothstepC2(0, self.stroke, edgeDist));
                const highight = if (p.x < 0) if (p.y < 0) nn else np else if (p.y < 0) pn else pp;
                jab = mix(highight, jab, gmath.smoothstepC2(0, halfStroke, edgeDist));
                return jab;
            }
        };
    }
};
