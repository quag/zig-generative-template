const std = @import("std");
const Allocator = std.mem.Allocator;

const ShaderConfig = @import("shaderconfig.zig").ShaderConfig;

const Jazbz = @import("jabz.zig").Jazbz(f64);
const Srgb = @import("jabz.zig").Srgb(u8);
const gmath = @import("gmath.zig").gmath(f64);

pub fn SsaaShader(width: f64, height: f64, ssaa: usize, comptime T: type) type {
    const mixVectors = makeMixVectors(width, height, ssaa);
    const meanFactor = 1.0 / @intToFloat(f64, mixVectors.len);

    const wider = width > height;
    const taller = height > width;
    const x0 = if (wider) (width - height) / 2 else 0;
    const y0 = if (taller) (height - width) / 2 else 0;
    const x1 = if (wider) width - x0 else width;
    const y1 = if (taller) height - y0 else height;

    return struct {
        const Self = @This();

        chain: T,

        pub fn init(allocator: *Allocator, config: ShaderConfig) !Self {
            return Self{
                .chain = try T.init(allocator, config),
            };
        }

        pub fn deinit(self: *const Self, allocator: *Allocator) void {
            self.chain.deinit(allocator);
        }

        pub fn shade(self: *const Self, x: usize, y: usize) Srgb {
            const x01 = gmath.coMix(x0, x1, @intToFloat(f64, x));
            const y01 = gmath.coMix(y0, y1, @intToFloat(f64, y));

            var jab = Jazbz{};
            for (mixVectors) |mv| {
                jab = Jazbz.JazbzField.add(jab, self.chain.shade(x01 + mv.x, y01 + mv.y));
            }

            jab.j *= meanFactor;
            jab.azbz.az *= meanFactor;
            jab.azbz.bz *= meanFactor;
            return jab.toSrgb(u8);
        }
    };
}

const MixVector = struct { x: f64, y: f64 };

fn makeMixVectors(width: f64, height: f64, comptime n: usize) [n * n]MixVector {
    const nf = @intToFloat(f64, n);
    const xScale = 1 / (nf * width);
    const yScale = 1 / (nf * height);
    var result: [n * n]MixVector = undefined;
    var y: usize = 0;
    while (y < n) : (y += 1) {
        const yf = @intToFloat(f64, y);
        var x: usize = 0;
        while (x < n) : (x += 1) {
            const xf = @intToFloat(f64, x);
            result[y * n + x] = .{
                .x = xf * xScale,
                .y = yf * yScale,
            };
        }
    }
    return result;
}
