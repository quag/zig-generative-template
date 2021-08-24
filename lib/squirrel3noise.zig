const math = @import("std").math;

// => https://youtu.be/LWFzPP8ZbdU?list=FLOZKYzNJILemcDKZwSBSoyg&t=2817 squirrel3 code in C++
// => https://youtu.be/LWFzPP8ZbdU?list=FLOZKYzNJILemcDKZwSBSoyg&t=3167 SquirrelRng API in C++
// => https://github.com/sublee/squirrel3-python/blob/master/squirrel3.py

pub fn squirrel3_u32(position: u32, seed: u32) u32 {
    const noise1 = 0xB5297A4D;
    const noise2 = 0x68E31DA4;
    const noise3 = 0x1B56C4E9;

    const m1 = position *% noise1 +% seed;
    const m2 = (m1 ^ (m1 >> 8)) +% noise2;
    const m3 = (m2 ^ (m2 << 8)) *% noise3;
    const m4 = m3 ^ (m3 >> 8);
    return m4;
}

pub fn u32_(position: u32, seed: u32) u32 {
    return squirrel3_u32(position, seed);
}

pub fn u32LtBiased(position: u32, seed: u32, limit: u32) u32 {
    return @intCast(u32, @intCast(u64, u32_(position, seed)) * limit >> 32);
}

pub fn mixiBiased(position: u32, seed: u32, low: u32, high: u32) u32 {
    return u32LtBiased(position, seed, high - low + 1) + low;
}

pub fn f01(position: u32, seed: u32) f64 {
    return @intToFloat(f64, u32_(position, seed)) / 0xFFFFFFFF;
}

pub fn mixf(position: u32, seed: u32, low: f64, high: f64) f64 {
    return f01(position, seed) * (high - low) + low;
}

pub fn chance(position: u32, seed: u32, probability: f64) bool {
    return u32_(position, seed) < @floatToInt(u32, probability * 0xFFFFFFFF);
}

pub const SquirrelU32Noise = struct {
    const Self = @This();

    seed: u32 = 0,

    pub fn init(seed: u32) Self {
        return .{ .seed = seed };
    }

    pub fn u32_(self: *const Self, position: u32) u32 {
        return squirrel3_u32(position, self.seed);
    }
};

pub const SquirrelU32Rng = struct {
    const Self = @This();

    position: u32 = 0,
    seed: u32 = 0,

    pub fn init(seed: u32) Self {
        return .{ .seed = seed };
    }

    pub fn u32_(self: *Self) u32 {
        const result = squirrel3_u32(self.position, self.seed);
        self.position += 1;
        return result;
    }
};

pub fn boxMuller(mu: f64, sigma: f64, uniform1: f64, uniform2: f64) f64 {
    // TODO: assert uniform1 > epsilon
    const mag = sigma * math.sqrt(math.ln(uniform1) * -2);
    const tau: f64 = 6.28318530717958647;
    const z0 = math.cos(uniform2 * tau) * mag + mu;
    //const z1 = math.sin(tau * uniform2) * mag + mu; // second random gausian value (two random numbers in, two out)
    return z0;
}

pub fn MakeRng(comptime U32Rng: type) type {
    return struct {
        const Self = @This();

        source: U32Rng,

        pub fn init(seed: u32) Self {
            return .{ .source = U32Rng.init(seed) };
        }

        pub fn u32_(self: *Self) u32 {
            return self.source.u32_();
        }

        pub fn rng(self: *Self) Self {
            return Self.init(self.u32_());
        }

        pub fn u32LtBiased(self: *Self, limit: u32) u32 {
            return @intCast(u32, @intCast(u64, self.u32_()) * limit >> 32);
        }

        pub fn u32Lt(self: *Self, limit: u32) u32 {
            const limit64 = @intCast(u64, limit);
            const t = (((1 << 32) - limit64) * limit64) >> 32;
            while (true) {
                const x = self.u32_();
                if (x >= t) {
                    return @intCast(u32, (x * limit64) >> 32);
                }
            }
        }

        pub fn mixi(self: *Self, low: u32, high: u32) u32 {
            return self.u32Lt(high - low + 1) + low;
        }

        pub fn mixiBiased(self: *Self, low: u32, high: u32) u32 {
            return self.u32LtBiased(high - low + 1) + low;
        }

        pub fn f01(self: *Self) f64 {
            return @intToFloat(f64, self.u32_()) / 0xFFFFFFFF;
        }

        pub fn mixf(self: *Self, low: f64, high: f64) f64 {
            return self.f01() * (high - low) + low;
        }

        pub fn quantize01(self: *Self, n: u32) f64 {
            return @intToFloat(f64, self.u32Lt(n)) / @intToFloat(f64, n);
        }

        pub fn chance(self: *Self, probability: f64) bool {
            return self.u32_() < @floatToInt(u32, probability * 0xFFFFFFFF);
        }

        pub fn normal(self: *Self, mu: f64, sigma: f64) f64 {
            return boxMuller(mu, sigma, self.f01(), self.f01());
        }
    };
}

pub const SquirrelRng = MakeRng(SquirrelU32Rng);
pub const squirrelRng = SquirrelRng.init;

pub fn MakeNoise(comptime U32Noise: type) type {
    return struct {
        const Self = @This();

        noise: U32Noise,

        pub fn init(seed: u32) Self {
            return .{ .noise = U32Noise.init(seed) };
        }

        pub fn u32_(self: *const Self, position: u32) u32 {
            return self.noise.u32_(position);
        }

        pub fn u32LtBiased(self: *const Self, limit: u32, position: u32) u32 {
            return @intCast(u32, @intCast(u64, self.u32_(position)) * limit >> 32);
        }

        pub fn u32Lt(self: *const Self, limit: u32, position: u32) u32 {
            const limit64 = @intCast(u64, limit);
            const t = (((1 << 32) - limit64) * limit64) >> 32;
            var i = 0;
            while (true) {
                const x = self.u32_(position +% i);
                if (x >= t) {
                    return @intCast(u32, (x * limit64) >> 32);
                }
                i += 1;
            }
        }

        pub fn mixi(self: *const Self, low: u32, high: u32, position: u32) u32 {
            return self.u32Lt(high - low + 1, position) + low;
        }

        pub fn mixiBiased(self: *const Self, low: u32, high: u32, position: u32) u32 {
            return self.u32LtBiased(high - low + 1, position) + low;
        }

        pub fn f01(self: *const Self, position: u32) f64 {
            return @intToFloat(f64, self.u32_(position)) / 0xFFFFFFFF;
        }

        pub fn mixf(self: *const Self, low: f64, high: f64, position: u32) f64 {
            return self.f01(position) * (high - low) + low;
        }

        pub fn chance(self: *const Self, probability: f64, position: u32) bool {
            return self.u32_(position) < @floatToInt(u32, probability * 0xFFFFFFFF);
        }

        pub fn normal(self: *const Self, mu: f64, sigma: f64, position1: u32, position2: u32) f64 {
            return boxMuller(mu, sigma, self.f01(position1), self.f01(position2));
        }
    };
}

pub const SquirrelNoise = MakeNoise(SquirrelU32Noise);
pub const squirrelNoise = SquirrelNoise.init;
