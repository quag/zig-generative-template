pub fn main() !void {
    try renderer.render(.{
        .Shader = SimpleBlendShader,
        //.Shader = CheckerShader,
        //.Shader = BandingShader,
        //.Shader = CliffordAttractorShader,
        //.Shader = JuliaSetShader,
        //.Shader = SimplexNoiseShader,
        //.Shader = GeometryShader,
        //.Shader = QuantizeShader,
        //.Shader = IntNoiseShader,
        //.Shader = SurfaceNormalShader,

        .preview = true,
        .memoryLimitMiB = 128,
        .ssaa = 3,
        .preview_ssaa = 1,
        .preview_samples = 600000,
        .frames = 1,
        //.frames = 30 * 8, // ffmpeg -r 30 -f image2 -i 'frame-%06d.png' -vcodec libx264 -pix_fmt yuv420p -profile:v main -level 3.1 -preset medium -crf 23 -x264-params ref=4 -movflags +faststart out.mp4

        .path = "out/out.png",
        .frameTemplate = "out/frame-{d:0>6}.png",

        .res = Resolutions.Instagram.square,
        //.res = Resolutions.Instagram.portrait,
        //.res = Resolutions.Instagram.landscape,
        //.res = Resolutions.Prints._8x10,
        //.res = comptime Resolutions.Prints._8x10.landscape(),
        //.res = Resolutions.Screen._4k,
        //.res = Resolutions.Screen._1080p,
        //.res = Resolutions.Wallpapers.iosParallax,
        //.res = comptime Resolutions.Prints._5x15.landscape(),
        //.res = Resolutions.Prints._5x15,
        //.res = @import("lib/resolutions.zig").Res{ .width = 256, .height = 256 },
    });
}

const SimpleBlendShader = struct {
    const Self = @This();
    pub fn init(allocator: *Allocator, config: renderer.ShaderConfig) !Self {
        return Self{};
    }

    pub fn deinit(self: *const Self, allocator: *Allocator) void {}

    pub fn shade(self: *const Self, x: f64, y: f64) Jazbz {
        return mix(
            mix(colors.goldenYellow, colors.seaBlue, saturate(x)),
            mix(colors.navyBlue, colors.bloodRed, saturate(x)),
            saturate(y),
        );
    }
};

const CheckerShader = struct {
    const Self = @This();
    pub fn init(allocator: *Allocator, config: renderer.ShaderConfig) !Self {
        return Self{};
    }

    pub fn deinit(self: *const Self, allocator: *Allocator) void {}

    pub fn shade(self: *const Self, x: f64, y: f64) Jazbz {
        return (comptime @import("lib/debug_shaders.zig").CheckedBackground(16)).content(colors.neonGreen, x, y);
    }
};

const BandingShader = struct {
    const Self = @This();
    pub fn init(allocator: *Allocator, config: renderer.ShaderConfig) !Self {
        return Self{};
    }

    pub fn deinit(self: *const Self, allocator: *Allocator) void {}

    pub fn shade(self: *const Self, x: f64, y: f64) Jazbz {
        if (x >= 0 and x <= 1 and y >= 0 and y <= 1) {
            const banding = @import("lib/banding.zig").Banding(pattern, (1 << 6) * phi, 640).sample(x, y);
            return mix(colors.goldenYellow, colors.bloodRed, banding);
        } else {
            return colors.navyBlue;
        }
    }

    fn pattern(x: f64, y: f64) [2]f64 {
        return [_]f64{
            x * y,
            y + x * x,
        };
    }
};

const CliffordAttractorShader = struct {
    const Self = @This();

    const Pixel = struct {
        count: usize = 0,
    };

    const Screen = @import("lib/screen.zig").Screen;
    const PixelScreen = Screen(Pixel);

    screen: PixelScreen,
    countCorrection: f64 = 1,

    pub fn init(allocator: *Allocator, config: renderer.ShaderConfig) !Self {
        var self = Self{
            .screen = try PixelScreen.init(allocator, config.res.width, config.res.height, .{ .count = 0 }),
        };
        errdefer self.screen.deinit();

        var n: usize = 4 << 20;
        const a = 1.7;
        const b = 1.7;
        const c = 0.6;
        const d = 1.2;
        const scale = comptime math.max(if (c < 0) -c else c, if (d < 0) -d else d) + 1.0;
        var x: f64 = a;
        var y: f64 = b;
        while (n != 0) : (n -= 1) {
            if (self.screen.ref(coMix(-scale, scale, x), coMix(-scale, scale, y))) |pixel| {
                pixel.count += 1;
            }
            const x1 = math.sin(a * y) + c * math.cos(a * x);
            const y1 = math.sin(b * x) + d * math.cos(b * y);
            x = x1;
            y = y1;
        }

        var highest: usize = 1;
        for (self.screen.cells) |pixel| {
            if (pixel.count > highest) {
                highest = pixel.count;
            }
        }
        self.countCorrection = 1 / @intToFloat(f64, highest);
        return self;
    }

    pub fn deinit(self: *const Self, allocator: *Allocator) void {
        self.screen.deinit();
    }

    pub fn shade(self: *const Self, x: f64, y: f64) Jazbz {
        if (self.screen.get(x, y)) |pixel| {
            const count = @intToFloat(f64, pixel.count) * self.countCorrection;
            return mix(colors.white, colors.darkGreen, gmath.mapDynamicRange(0, 1, 0, 1, 0.3, 0.5, 1.0, count));
        } else {
            return colors.white;
        }
    }
};

const JuliaSetShader = struct {
    const Self = @This();
    pub fn init(allocator: *Allocator, config: renderer.ShaderConfig) !Self {
        return Self{};
    }

    pub fn deinit(self: *const Self, allocator: *Allocator) void {}

    pub fn shade(self: *const Self, x: f64, y: f64) Jazbz {
        const nLimit: usize = 1 << 9;
        const cx = -0.76;
        const cy = -0.09;
        var zx = mix(-0.8, 0.8, y);
        var zy = mix(-0.8, 0.8, x);
        var xx = zx * zx;
        var yy = zy * zy;
        var n: usize = nLimit;
        while (n != 0 and xx + yy < 4) : (n -= 1) {
            zy *= zx;
            zy *= 2;
            zy += cy;
            zx = xx - yy + cx;
            xx = zx * zx;
            yy = zy * zy;
        }
        const n01 = coMix(0, comptime @intToFloat(f64, nLimit), @intToFloat(f64, n));
        return rainbowRamp(n01).scaleJ(vignette(x, y));
    }

    fn rainbowRamp(x: f64) Jazbz {
        return Jazbz{
            .j = mix(0.0, 0.7, gmath.quantize(1.0 / 8.0, gmath.sigmoidC3(sq(x)))),
            .azbz = AzBz.initCh(0.6, fract(x * 12)),
        };
    }

    fn vignette(x: f64, y: f64) f64 {
        return mix(0.4, 1, 1.3 - (1 - (1 - sq(x)) * (1 - sq(y))));
    }
};

const SimplexNoiseShader = struct {
    const sn = @import("lib/simplexnoise1234.zig");

    const Self = @This();
    pub fn init(allocator: *Allocator, config: renderer.ShaderConfig) !Self {
        return Self{};
    }

    pub fn deinit(self: *const Self, allocator: *Allocator) void {}

    pub fn shade(self: *const Self, x: f64, y: f64) Jazbz {
        const h1 = sn.noise2(mix(100, 104, x), mix(200, 204, y)) * 1.0;
        const h2 = sn.noise2(mix(300, 308, x), mix(400, 408, y)) * 0.5;
        const h3 = sn.noise2(mix(500, 516, x), mix(600, 616, y)) * 0.25;
        const cloud = coMix(-1.75, 1.75, h1 + h2 + h3);
        var result = mix(colors.goldenYellow, colors.darkPurple, cloud);
        result.j = gmath.sigmoidSkew(mix(0.0, 0.4, y), 0.5, result.j);
        return result;
    }
};

const GeometryShader = struct {
    const geom = @import("lib/geom.zig");
    const sdf2 = @import("lib/sdf2.zig");
    const brdf = @import("lib/brdf.zig");
    const sn = @import("lib/simplexnoise1234.zig");

    const Self = @This();
    pub fn init(allocator: *Allocator, config: renderer.ShaderConfig) !Self {
        return Self{};
    }

    pub fn deinit(self: *const Self, allocator: *Allocator) void {}

    pub fn shade(self: *const Self, x: f64, y: f64) Jazbz {
        const circleRadius = comptime mix(0.1, 0.16666666666666666, 0.5);
        const inset = 0.33333333333333333;
        const offset = comptime v2(0.025, -0.0125);

        const Dp1 = DotPipe(comptime v2(inset, inset).add(offset), circleRadius, V2.degree90);
        const Dp2 = DotPipe(comptime v2(1 - inset, 1 - inset).add(offset), circleRadius, V2.degree0);
        const Dp3 = DotPipe(comptime v2(inset, 1 - inset).add(offset), circleRadius, V2.degree315);

        const p = v2(x, y);
        const p1 = Dp1.signedDists(p);
        const p2 = Dp2.signedDists(p);
        const p3 = Dp3.signedDists(p);

        const dotSd = p1.dot.merge(p2.dot).merge(p3.dot);
        const pipeSd = dotSd.merge(p1.pipe).merge(p2.pipe).merge(p3.pipe);

        const redMat = Surface{
            .material = .{
                .baseColor = mix(colors.leafGreen, colors.black, mix(0.0, 0.25, y)),
                .reflectance = 0.2,
                .roughness = 0.5,
            },
            .noise = 1,
            .noiseSize = 192,
        };

        const blackMat = Surface{
            .material = .{
                .baseColor = colors.almostBlack,
                .metallic = 1,
                .clearcoat = 1,
                .clearcoatRoughness = 0.35,
            },
            .noise = 0,
            .noiseSize = 192,
        };

        const whiteMat = Surface{
            .material = .{
                .baseColor = colors.eggShell,
            },
            .noise = 0,
            .noiseSize = 192,
        };

        const smooth = 0.001;
        var mat = redMat;
        mat = mix(mat, blackMat, pipeSd.smoothstepC3(smooth, 0));
        mat = mix(mat, whiteMat, dotSd.smoothstepC3(smooth, 0));

        const prepared = mat.material.prepare();
        const point = v3(p.x, p.y, 0);
        const h1 = sn.noise2(mix(100, 100 + mat.noiseSize, x), mix(200, 200 + mat.noiseSize, y));
        const h2 = sn.noise2(mix(300, 300 + mat.noiseSize, x), mix(400, 400 + mat.noiseSize, y));
        const normal = v3(h1 * mat.noise, h2 * mat.noise, 1).normalize();

        const camera = v3(0.5, 0.5, 128);
        const light1 = comptime v3(inset, inset, 0.5);
        const light2 = comptime v3(inset, 1 - inset, 0.5);
        const light3 = comptime v3(1 - inset, 1 - inset, 0.5);
        const sample1 = prepared.brdf(normal, camera.sub(point).normalize(), light1.sub(point).normalize()).scaleJ(1.2);
        const sample2 = prepared.brdf(normal, camera.sub(point).normalize(), light2.sub(point).normalize()).scaleJ(0.7);
        const sample3 = prepared.brdf(normal, camera.sub(point).normalize(), light3.sub(point).normalize()).scaleJ(0.8);

        var result = sample1.addLight(sample2).addLight(sample3).toJazbz();
        const blackPoint = 0.03;
        const whitePoint = 0.75;
        result.j = gmath.filmicDynamicRange(blackPoint, whitePoint, 0.4, 0.5, result.j);
        result.j = gmath.sigmoidSkew(0.3, 1 - y, result.j);
        result.j = saturate(result.j);
        return result;
    }

    const Surface = struct {
        material: brdf.Material,
        noise: f64 = 0,
        noiseSize: f64 = 0,

        pub fn mix(self: @This(), other: @This(), alpha: f64) @This() {
            return .{
                .material = gmath.mix(self.material, other.material, alpha),
                .noise = gmath.mix(self.noise, other.noise, alpha),
                .noiseSize = gmath.mix(self.noiseSize, other.noiseSize, alpha),
            };
        }
    };

    fn DotPipe(c: V2, r: f64, dir: V2) type {
        const n = dir;
        const e = n.rotate90();
        const s = n.rotate180();
        const w = n.rotate270();

        const circle = geom.Circle.rp(r, c);

        const line1 = geom.Line.pn(c.add(e.scale(r)), s);
        const line2 = geom.Line.pn(c.add(w.scale(r)), n);
        const line3 = geom.Line.pn(c, e);
        return struct {
            dot: sdf2.Sd,
            pipe: sdf2.Sd,

            fn signedDists(p: V2) @This() {
                return .{
                    .dot = dotSd(p),
                    .pipe = pipeSd(p),
                };
            }

            fn dotSd(p: V2) sdf2.Sd {
                return circle.signedDist(p);
            }

            fn pipeSd(p: V2) sdf2.Sd {
                const sd1 = line1.signedDistBefore(p);
                const sd2 = line2.signedDistBefore(p);
                const sd3 = line3.signedDistBefore(p);
                return sd1.match(sd2).cut(sd3);
            }
        };
    }
};

const QuantizeShader = struct {
    const sqn = @import("lib/squirrel3noise.zig");

    const Self = @This();
    pub fn init(allocator: *Allocator, config: renderer.ShaderConfig) !Self {
        return Self{};
    }

    pub fn deinit(self: *const Self, allocator: *Allocator) void {}

    pub fn shade(self: *const Self, x: f64, y: f64) Jazbz {
        const xq = gmath.quantize(0.1, x);
        const yq = gmath.quantize(0.1, y);
        const xf = gmath.fract(x / 0.1);
        const yf = gmath.fract(y / 0.1);

        var result = mix(
            mix(colors.white, colors.black, xq),
            mix(colors.navyBlue, colors.leafGreen, xq),
            yq,
        );
        result.j = mix(result.j, xf, mix(0.05, 0.0, yf));
        return result;
    }
};

const IntNoiseShader = struct {
    const gs = @import("lib/gridsize.zig");
    const sqn = @import("lib/squirrel3noise.zig");

    const Self = @This();

    const Gs = gs.GridSize(7, 7);

    const Cell = struct {
        vertex: V2,
        color: Jazbz,
    };

    grid: [Gs.len]Cell,

    pub fn init(allocator: *Allocator, config: renderer.ShaderConfig) !Self {
        var self = Self{
            .grid = undefined,
        };
        var rng = sqn.squirrelRng(0);
        for (self.grid) |*cell| {
            cell.vertex = .{
                .x = rng.f01(),
                .y = rng.f01(),
            };
            cell.color = Jazbz.initJch(rng.mixf(0.5, 0.8), 0.3, rng.f01());
        }
        return self;
    }

    pub fn deinit(self: *const Self, allocator: *Allocator) void {}

    pub fn shade(self: *const Self, x: f64, y: f64) Jazbz {
        var result = colors.black;
        if (Gs.pos(x, y)) |centerPos| {
            var win_d: f64 = 1;
            var win_color = colors.white;
            for (centerPos.neighbors9()) |candidatePos| {
                if (candidatePos) |pos| {
                    const q = v2(pos.cellx(x), pos.celly(y));
                    const cell = &self.grid[pos.index];
                    const c = cell.vertex;
                    const d = saturate(c.distTo(q));

                    if (d < win_d) {
                        win_d = d;
                        win_color = cell.color;
                    }
                }
            }

            result = mix(result, win_color, coSq(1 - win_d));
            result.j = gmath.sigmoidSkew(0.3, 1 - y, result.j);
        }
        return result;
    }
};

const SurfaceNormalShader = struct {
    const geom = @import("lib/geom.zig");
    const sdf2 = @import("lib/sdf2.zig");
    const brdf = @import("lib/brdf.zig");
    const surf = @import("lib/surfacenormal.zig");

    const Self = @This();

    pub fn init(allocator: *Allocator, config: renderer.ShaderConfig) !Self {
        return Self{};
    }

    pub fn deinit(self: *const Self, allocator: *Allocator) void {}

    pub fn shade(self: *const Self, x: f64, y: f64) Jazbz {
        const p = v2(x, y);
        const circle = geom.Circle.rp(0.3, v2(0.5, 0.5));
        var layer = mix(colors.bloodRed, colors.goldenYellow, x);
        if (surf.EllipticalTorus.forCircle(circle, 0.15, 0.2, p)) |surface| {
            const material = brdf.Material{
                .baseColor = mix(colors.bloodRed, colors.goldenYellow, 1 - x),
                .reflectance = 0.4,
                .roughness = 0.6,
                .clearcoat = 1,
                .clearcoatRoughness = 0.3,
            };
            const shaded = surf.shade(surface, &material.prepare());
            layer = mix(layer, shaded, surface.blend.smoothstepC3(0.001, 0));
        }
        layer.j = gmath.sigmoidSkew(0.3, 1 - y, layer.j);
        layer.j = saturate(layer.j);
        return layer;
    }
};

pub const enable_segfault_handler: bool = true;

const std = @import("std");
const math = std.math;

const Allocator = std.mem.Allocator;

const renderer = @import("lib/renderer.zig");
const Resolutions = @import("lib/resolutions.zig").Resolutions;

const V2 = @import("lib/affine.zig").V2;
const V3 = @import("lib/affine.zig").V3;
const v2 = V2.init;
const v3 = V3.init;

const Jazbz = @import("lib/jabz.zig").Jazbz(f64);
const AzBz = Jazbz.AzBz;
const colors = @import("lib/colors.zig").Colors(Jazbz);

const gmath = @import("lib/gmath.zig").gmath(f64);
const fract = gmath.fract;
const clamp = gmath.clamp;
const saturate = gmath.saturate;
const linearstep = gmath.linearstep;
const smoothstepC1 = gmath.smoothstepC1;
const smoothstepC2 = gmath.smoothstepC2;
const smoothstepC3 = gmath.smoothstepC3;
const mix = gmath.mix;
const coMix = gmath.coMix;
const sq = gmath.sq;
const coSq = gmath.coSq;

const pi = gmath.pi;
const invPi = gmath.invPi;
const tau = gmath.tau;
const invTau = gmath.invTau;
const phi = gmath.phi;
const invPhi = gmath.invPhi;
const sqrt2 = gmath.sqrt2;
const invSqrt2 = gmath.invSqrt2;
const sqrt3 = gmath.sqrt3;
const halfSqrt3 = gmath.halfSqrt3;
