const std = @import("std");
const Allocator = std.mem.Allocator;

const ShaderConfig = @import("shaderconfig.zig").ShaderConfig;

const Jazbz = @import("jabz.zig").Jazbz(f64);
const Srgb = @import("jabz.zig").Srgb(u8);
const unitbounds = @import("unitbounds.zig");

pub fn SsaaShader(width: usize, height: usize, ssaa: usize, comptime T: type) type {
    const mixVectors = makeMixVectors(width, height, ssaa);
    const meanFactor = 1.0 / @intToFloat(f64, mixVectors.len);
    const ub = unitbounds.PosUTo01.forCenter(width, height);

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
            const pos = ub.toPos01(x, y);

            var jab = Jazbz{};
            for (mixVectors) |mv| {
                jab = Jazbz.JazbzField.add(jab, self.chain.shade(pos.x + mv.x, pos.y + mv.y));
            }

            jab.j *= meanFactor;
            jab.azbz.az *= meanFactor;
            jab.azbz.bz *= meanFactor;
            return jab.toSrgb(u8);
        }
    };
}

const MixVector = struct { x: f64, y: f64 };

fn makeMixVectors(width: usize, height: usize, comptime n: usize) [n * n]MixVector {
    const nf = @intToFloat(f64, n);
    const xScale = 1 / (nf * @intToFloat(f64, width));
    const yScale = 1 / (nf * @intToFloat(f64, height));
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
