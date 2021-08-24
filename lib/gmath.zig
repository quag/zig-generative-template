const math = @import("std").math;

fn StripComptime(comptime T: type) type {
    return switch (T) {
        comptime_float => f64,
        comptime_int => f64,
        else => T,
    };
}

fn hasMethod(comptime T: type, comptime name: []const u8) bool {
    return @typeInfo(T) == .Struct and @hasDecl(T, name);
}

pub fn gmath(comptime T: type) type {
    return struct {
        pub const pi: T = 3.14159265358979323;
        pub const invPi: T = 0.31830988618379067;
        pub const tau: T = 6.28318530717958647;
        pub const invTau: T = 0.15915494309189534;
        pub const phi: T = 1.61803398874989484;
        pub const invPhi: T = 0.61803398874989484;
        pub const sqrt2: T = 1.41421356237309504;
        pub const invSqrt2: T = 0.70710678118654752;
        pub const sqrt3: T = 1.73205080756887729;
        pub const halfSqrt3: T = 0.86602540378443865;

        pub const almostOne = 1.0 - math.epsilon(T);

        pub fn sq(x: T) T {
            return x * x;
        }

        pub fn pow3(x: T) T {
            return x * x * x;
        }

        pub fn pow4(x: T) T {
            const xx = x * x;
            return xx * xx;
        }

        pub fn pow5(x: T) T {
            const xx = x * x;
            return xx * xx * x;
        }

        pub fn pow6(x: T) T {
            const xx = x * x;
            return xx * xx * xx;
        }

        pub fn pow8(x: T) T {
            const xx = x * x;
            const xxxx = xx * xx;
            return xxxx * xxxx;
        }

        pub fn pow16(x: T) T {
            const xx = x * x;
            const xxxx = xx * xx;
            const xxxxxxxx = xxxx * xxxx;
            return xxxxxxxx * xxxxxxxx;
        }

        pub fn coSq(x: T) T {
            return 1 - (1 - x) * (1 - x);
        }

        pub fn coSqN(x: T, n: usize) T {
            var y = 1 - x;
            var i = n;
            while (i != 0) : (i -= 1) {
                y *= y;
            }
            return 1 - y;
        }

        pub fn sqrt01Approx(x: T) T {
            //const a = mix(0.1 * math.e, 1, x);
            //const b = coMix(-a, 1, x);
            //const y = (1 + a) - a / b;
            const fma1 = x * 0.72817181715409548 + 0.27182818284590452;
            const fma2 = x * 0.72817181715409548 + 1.27182818284590452;
            const fma3 = x * -0.72817181715409548 + -0.27182818284590452;
            const div1 = x / fma2;
            const div2 = fma1 / fma2;
            const add1 = div1 + div2;
            const div3 = fma3 / add1;
            const add2 = fma2 + div3;
            const y = add2;

            return y;
        }

        pub fn parabola(x: anytype) T {
            return 4 * x * (1 - x);
        }

        /// First derivative is 0 at 0 and 1.
        pub fn sigmoidC1(x: anytype) T {
            return x * x * mix(3, 1, x);
        }

        /// First and second derivatives are 0 at 0 and 1.
        pub fn sigmoidC2(x: anytype) T {
            return x * x * x * (x * (x * 6 - 15) + 10);
        }

        /// First, second and third derivatives are 0 at 0 and 1.
        pub fn sigmoidC3(x: anytype) T {
            const xx = x * x;
            return xx * xx * (x * (-20 * xx + 70 * x - 84) + 35);
        }

        pub fn fract(x: T) T {
            return @mod(x, 1);
        }

        pub fn quantize(quantum: anytype, x: anytype) T {
            return @trunc(x / quantum) * quantum;
        }

        pub fn clamp(e0: anytype, e1: anytype, x: anytype) T {
            return if (x < e0) e0 else if (x > e1) e1 else x;
        }

        pub fn bump(e0: anytype, e1: anytype, x: anytype) T {
            return if (x < e0 or x > e1) 0 else parabola(coMix(e0, e1, x));
        }

        pub fn saturate(x: anytype) T {
            return clamp(0, almostOne, x);
        }

        pub fn length1(x: T) T {
            return math.fabs(x);
        }

        pub fn length2(x: T, y: T) T {
            return math.hypot(T, x, y);
        }

        pub fn length2sq(x: anytype, y: anytype) T {
            return x * x + y * y;
        }

        pub fn coLength1(x: anytype) T {
            return 1 - math.fabs(x);
        }

        pub fn coLength2(x: T, y: T) T {
            return 1 - math.hypot(x, y);
        }

        pub fn fma(m: anytype, a: anytype, in: anytype) T {
            return in * m + a;
        }

        pub fn pow(x: anytype, a: anytype) T {
            return math.pow(T, x, a);
        }

        pub fn copysign(x: anytype, s: anytype) T {
            return math.copysign(T, x, s);
        }

        pub fn powCopySign(x: anytype, a: anytype) T {
            return copysign(pow(x, a), x);
        }

        pub fn fmapow(m: anytype, a: anytype, p: anytype, in: anytype) T {
            return powCopySign(fma(m, a, in), p);
        }

        pub fn mix_(lowOut: anytype, highOut: anytype, in: anytype) T {
            return fma(highOut - lowOut, lowOut, in);
        }

        fn comptimeFloat(comptime x: anytype) comptime_float {
            comptime {
                return switch (@TypeOf(x)) {
                    comptime_float => x,
                    comptime_int => @intToFloat(T, x),
                    else => @compileError("comptimeFloat not implemented for " ++ @typeName(T)),
                };
            }
        }

        pub fn coMix_(lowIn: anytype, highIn: anytype, in: anytype) T {
            if ((@TypeOf(lowIn) == comptime_float or @TypeOf(lowIn) == comptime_int) and (@TypeOf(highIn) == comptime_float or @TypeOf(highIn) == comptime_int)) {
                const m = 1.0 / (comptimeFloat(highIn) - comptimeFloat(lowIn));
                return fma(m, -comptimeFloat(lowIn) * m, in);
            } else {
                return (in - lowIn) / (highIn - lowIn); // Divide and two subtractions.
            }
        }

        pub fn mix(a: anytype, b: anytype, x: f64) StripComptime(@TypeOf(a)) {
            const A = @TypeOf(a);
            return if (comptime hasMethod(A, "mix")) A.mix(a, b, x) else mix_(a, b, x);
        }

        pub fn coMix(a: anytype, b: anytype, x: f64) StripComptime(@TypeOf(a)) {
            const A = @TypeOf(a);
            return if (comptime hasMethod(A, "coMix")) A.coMix(a, b, x) else coMix_(a, b, x);
        }

        pub fn map(a: anytype, b: anytype, c: anytype, d: anytype, x: f64) StripComptime(@TypeOf(a)) {
            return mix(c, d, coMix(a, b, x));
        }

        pub fn step(in: anytype, edge: anytype) T {
            if (in < edge) {
                return 0;
            } else {
                return 1;
            }
        }

        pub fn coStep(in: anytype, edge: anytype) T {
            if (in >= edge) {
                return 0;
            } else {
                return 1;
            }
        }

        pub fn linearstep(e0: anytype, e1: anytype, x: anytype) T {
            return saturate(coMix(e0, e1, x));
        }

        pub fn sqstep(e0: anytype, e1: anytype, x: anytype) T {
            return sq(linearstep(e0, e1, x));
        }

        pub fn cosqstep(e0: anytype, e1: anytype, x: anytype) T {
            return coSq(linearstep(e0, e1, x));
        }

        pub fn smoothstepC1(e0: anytype, e1: anytype, x: anytype) T {
            return sigmoidC1(linearstep(e0, e1, x));
        }

        pub fn smoothstepC2(e0: anytype, e1: anytype, x: anytype) T {
            return sigmoidC2(linearstep(e0, e1, x));
        }

        pub fn smoothstepC3(e0: anytype, e1: anytype, x: anytype) T {
            return sigmoidC3(linearstep(e0, e1, x));
        }

        pub fn logstep(e0: anytype, e1: anytype, x: anytype) T {
            return linearstep(0, log1p(e1 - e0), log1p(math.max(0, x - e0)));
        }

        pub fn logStrengthstep(e0: anytype, e1: anytype, strength: anytype, x: anytype) T {
            const linear = linearstep(e0, e1, x);
            if (strength <= 1e-5) {
                return linear;
            } else {
                return log1p(linear * strength) / log1p(strength);
            }
        }

        pub fn sigmoidSkew(strength: anytype, skew: anytype, in: anytype) T {
            const skewed = mix(sq(in), coSq(in), skew);
            const sCurved = smoothstepC3(0, 1, skewed);
            const dampened = mix(in, sCurved, strength);
            return dampened;
        }

        // Adds a filmic curve and input range on top of liftGammaGain.
        // defaults: mapDynamicRange(0, 1, 0, 1, 1, 0, 0.5, x)
        // (in-range, out-range, power, linear/s-curve, s-curve-skew)
        pub fn mapDynamicRange(lowIn: anytype, highIn: anytype, lowOut: anytype, highOut: anytype, power: anytype, sCurveStrength: anytype, sCurveSkew: anytype, in: anytype) T {
            const inputRanged = linearstep(lowIn, highIn, in);
            const gammaed = pow(inputRanged, power);
            const sCurved = sigmoidSkew(sCurveStrength, sCurveSkew, gammaed);
            const outputRanged = mix(lowOut, highOut, sCurved);
            return outputRanged;
        }

        // Adds a filmic curve and input range on top of liftGammaGain.
        // defaults: mapDynamicRange(0, 1, 0, 1, 1, 0, 0.5, x)
        // (in-range, out-range, power, linear/s-curve, s-curve-skew)
        pub fn mapDynamicRangeLog(lowIn: anytype, highIn: anytype, lowOut: anytype, highOut: anytype, power: anytype, sCurveStrength: anytype, sCurveSkew: anytype, in: anytype) T {
            const inputRanged = linearstep(lowIn, highIn, in);
            const logged = math.log1p(inputRanged);
            const gammaed = pow(logged, power);
            const sCurved = sigmoidSkew(sCurveStrength, sCurveSkew, gammaed);
            const outputRanged = mix(lowOut, highOut, sCurved);
            return outputRanged;
        }

        pub fn filmicDynamicRange(blackPoint: anytype, whitePoint: anytype, sCurveStrength: anytype, sCurveSkew: anytype, in: anytype) T {
            return sigmoidSkew(sCurveStrength, sCurveSkew, logstep(blackPoint, whitePoint, in));
        }

        pub fn log1p(x: anytype) T {
            return switch (@TypeOf(x)) {
                comptime_int, comptime_float => comptime math.log1p(@as(T, x)),
                else => math.log1p(x),
            };
        }

        pub fn expm1(x: anytype) T {
            return switch (@TypeOf(x)) {
                comptime_int, comptime_float => comptime math.expm1(@as(T, x)),
                else => math.expm1(x),
            };
        }

        // https://lowepost.com/resources/colortheory/cdl-r9/
        // ASC-CDL: https://blender.stackexchange.com/questions/55231/what-is-the-the-asc-cdl-node
        pub fn slopeOffsetPower(slope: anytype, offset: anytype, power: anytype, x: anytype) T {
            return fmapow(slope, offset, power, x);
        }

        // Different characterisation of slopeOffsetPower.
        pub fn mixPow(low: anytype, high: anytype, power: anytype, x: anytype) T {
            return powCopySign(mix(low, high, x), power);
        }

        // Different characterisation of slopeOffsetPower.
        pub fn coMixPow(low: anytype, high: anytype, power: anytype, x: anytype) T {
            return powCopySign(coMix(low, high, in), power);
        }

        pub fn powMix(power: anytype, lowOut: anytype, highOut: anytype, in: anytype) T {
            return mix(lowOut, highOut, powCopySign(in, power));
        }

        // http://filmicworlds.com/blog/minimal-color-grading-tools/
        // Use slopeOffsetPower instead.
        pub fn liftGammaGain(lift: anytype, gamma: anytype, gain: anytype, x: anytype) T {
            return powMix(gamma, lift, gain, x);
        }

        /// https://knarkowicz.wordpress.com/2016/01/06/aces-filmic-tone-mapping-curve/
        pub fn tonemapAces(j: T) T {
            //    j⋅(2.51⋅j + 0.03)
            // ────────────────────────
            // j⋅(2.43⋅j + 0.59) + 0.14
            return j * (2.51 * j + 0.03) / (j * (j * 2.43 + 0.59) + 0.14);
        }

        pub fn rrtAndOdtFit(j: T) T {
            //    j⋅(j + 0.0245786) - 9.0537e-5
            // ────────────────────────────────────
            // j⋅(0.983729⋅j + 0.432951) + 0.238081
            return (j * (j + 0.0245786) - 9.0537e-5) / (j * (0.983729 * j + 0.432951) + 0.238081);
        }

        /// https://www.iquilezles.org/www/articles/functions/functions.htm
        pub fn almostIdentity(y0: T, xc: T, x: T) T {
            if (x > xc) {
                return x;
            } else {
                const t = x / xc;
                return (t * (2 * y0 + xc) + (2 * xc - 3 * y0)) * t * t + y0;
            }
        }
    };
}
