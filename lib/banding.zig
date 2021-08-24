const phi: f64 = 1.61803398874989484;

pub fn Banding(partsFn: anytype, div: f64, imgSize: usize) type {
    const samples = blk: {
        const divi: f64 = 1 / div;
        const samplesn = @floatToInt(usize, 2 * phi * @intToFloat(f64, imgSize) / div);
        var r: [samplesn]f64 = undefined;
        for (r) |*sample, i| {
            sample.* = divi * @intToFloat(f64, i) / @intToFloat(f64, r.len);
        }
        break :blk r;
    };

    const sumNorm = 1.0 / @intToFloat(f64, samples.len * samples.len);

    return struct {
        pub fn sample(x: f64, y: f64) f64 {
            var sum: usize = 0;
            for (samples) |dy| {
                const jy = y + dy;
                for (samples) |dx| {
                    const jx = x + dx;
                    var xor: usize = 0;
                    for (partsFn(jx, jy)) |part| {
                        xor ^= @floatToInt(usize, part * div) & 1;
                    }
                    sum += xor;
                }
            }
            return @intToFloat(f64, sum) * sumNorm;
        }
    };
}

fn checkers(x: f64, y: f64) [2]f64 {
    return [_]f64{
        x,
        y,
    };
}

//const banding = Banding(checkers, (1 << 6) * phi, pngSize).sample;
