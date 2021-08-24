// Ported to zig. Copyright © 2019, Jonathan Wright.
//
// -----------------------------------------------------------------
//
// SimplexNoise1234
// Copyright © 2003-2011, Stefan Gustavson
//
// Contact: stegu@itn.liu.se
//
// This library is public domain software, released by the author
// into the public domain in February 2011. You may do anything
// you like with it. You may even remove all attributions,
// but of course I'd appreciate it if you kept my name somewhere.
//
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// General Public License for more details.

pub fn noise1(x: f64) f64 {
    const j0 = FASTFLOOR(x);
    const j1 = j0 + 1;
    const x0 = x - @intToFloat(f64, j0);
    const x1 = x0 - 1;

    var t0 = 1 - x0 * x0;
    if (t0 < 0) {
        t0 = 0;
    } else {
        t0 *= t0;
    }
    const n0 = t0 * t0 * grad1(perm[j0 & 0xff], x0);

    var t1 = 1 - x1 * x1;
    if (t1 < 0) {
        t1 = 0;
    } else {
        t1 *= t1;
    }
    const n1 = t1 * t1 * grad1(perm[j1 & 0xff], x1);
    return 0.395 * (n0 + n1);
}

pub fn noise2(x: f64, y: f64) f64 {
    const F2 = 0.36602540378443865; // F2 = 0.5*(sqrt(3.0)-1.0)
    const G2 = 0.21132486540518712; // G2 = (3.0-Math.sqrt(3.0))/6.0

    const s = (x + y) * F2;
    const i = FASTFLOOR(x + s);
    const j = FASTFLOOR(y + s);

    const t = @intToFloat(f64, i +% j) * G2;
    const x0 = x + t - @intToFloat(f64, i);
    const y0 = y + t - @intToFloat(f64, j);

    var i1_: usize = 0;
    var j1: usize = 1;

    if (x0 > y0) {
        i1_ = 1;
        j1 = 0;
    }

    const ii = i & 0xff;
    const jj = j & 0xff;
    const hash1 = perm[ii + perm[jj]];
    const hash2 = perm[ii + i1_ + perm[jj + j1]];
    const hash3 = perm[ii + 1 + perm[jj + 1]];

    const x1 = x0 - @intToFloat(f64, i1_) + G2;
    const y1 = y0 - @intToFloat(f64, j1) + G2;
    const x2 = x0 - 1 + G2 * 2.0;
    const y2 = y0 - 1 + G2 * 2.0;

    var t0 = 0.5 - x0 * x0 - y0 * y0;
    const n0 = if (t0 < 0) 0 else blk: {
        t0 *= t0;
        break :blk t0 * t0 * grad2(hash1, x0, y0);
    };

    var t1 = 0.5 - x1 * x1 - y1 * y1;
    const n1 = if (t1 < 0) 0 else blk: {
        t1 *= t1;
        break :blk t1 * t1 * grad2(hash2, x1, y1);
    };

    var t2 = 0.5 - x2 * x2 - y2 * y2;
    const n2 = if (t2 < 0) 0 else blk: {
        t2 *= t2;
        break :blk t2 * t2 * grad2(hash3, x2, y2);
    };

    return 40 * (n0 + n1 + n2);
}

pub fn noise3(x: f64, y: f64, z: f64) f64 {
    const F3 = 0.33333333333333333;
    const G3 = 0.16666666666666666;

    const s = (x + y + z) * F3;
    const xs = x + s;
    const ys = y + s;
    const zs = z + s;
    const i = FASTFLOOR(xs);
    const j = FASTFLOOR(ys);
    const k = FASTFLOOR(zs);

    const t = @intToFloat(f64, i +% j +% k) * G3;
    const X0 = @intToFloat(f64, i) - t;
    const Y0 = @intToFloat(f64, j) - t;
    const Z0 = @intToFloat(f64, k) - t;
    const x0 = x - X0;
    const y0 = y - Y0;
    const z0 = z - Z0;

    var i1_: usize = 0;
    var i2_: usize = 0;
    var j1: usize = 0;
    var j2: usize = 0;
    var k1: usize = 0;
    var k2: usize = 0;

    if (x0 >= y0) {
        if (y0 >= z0) {
            i1_ = 1;
            j1 = 0;
            k1 = 0;
            i2_ = 1;
            j2 = 1;
            k2 = 0;
        } else if (x0 >= z0) {
            i1_ = 1;
            j1 = 0;
            k1 = 0;
            i2_ = 1;
            j2 = 0;
            k2 = 1;
        } else {
            i1_ = 0;
            j1 = 0;
            k1 = 1;
            i2_ = 1;
            j2 = 0;
            k2 = 1;
        }
    } else {
        if (y0 < z0) {
            i1_ = 0;
            j1 = 0;
            k1 = 1;
            i2_ = 0;
            j2 = 1;
            k2 = 1;
        } else if (x0 < z0) {
            i1_ = 0;
            j1 = 1;
            k1 = 0;
            i2_ = 0;
            j2 = 1;
            k2 = 1;
        } else {
            i1_ = 0;
            j1 = 1;
            k1 = 0;
            i2_ = 1;
            j2 = 1;
            k2 = 0;
        }
    }

    const x1 = x0 - @intToFloat(f64, i1_) + G3;
    const y1 = y0 - @intToFloat(f64, j1) + G3;
    const z1 = z0 - @intToFloat(f64, k1) + G3;
    const x2 = x0 - @intToFloat(f64, i2_) + 2.0 * G3;
    const y2 = y0 - @intToFloat(f64, j2) + 2.0 * G3;
    const z2 = z0 - @intToFloat(f64, k2) + 2.0 * G3;
    const x3 = x0 - 1 + 3.0 * G3;
    const y3 = y0 - 1 + 3.0 * G3;
    const z3 = z0 - 1 + 3.0 * G3;

    const ii = i & 0xff;
    const jj = j & 0xff;
    const kk = k & 0xff;

    var t0 = 0.6 - x0 * x0 - y0 * y0 - z0 * z0;
    const n0 = if (t0 < 0) 0 else blk: {
        t0 *= t0;
        break :blk t0 * t0 * grad3(perm[ii + perm[jj + perm[kk]]], x0, y0, z0);
    };

    var t1 = 0.6 - x1 * x1 - y1 * y1 - z1 * z1;
    const n1 = if (t1 < 0) 0 else blk: {
        t1 *= t1;
        break :blk t1 * t1 * grad3(perm[ii + i1_ + perm[jj + j1 + perm[kk + k1]]], x1, y1, z1);
    };

    var t2 = 0.6 - x2 * x2 - y2 * y2 - z2 * z2;
    const n2 = if (t2 < 0) 0 else blk: {
        t2 *= t2;
        break :blk t2 * t2 * grad3(perm[ii + i2_ + perm[jj + j2 + perm[kk + k2]]], x2, y2, z2);
    };

    var t3 = 0.6 - x3 * x3 - y3 * y3 - z3 * z3;
    const n3 = if (t3 < 0) 0 else blk: {
        t3 *= t3;
        break :blk t3 * t3 * grad3(perm[ii + 1 + perm[jj + 1 + perm[kk + 1]]], x3, y3, z3);
    };

    return 32 * (n0 + n1 + n2 + n3);
}

pub fn noise4(x: f64, y: f64, z: f64, w: f64) f64 {
    const F4 = 0.30901699437494742; // F4 = (Math.sqrt(5.0)-1.0)/4.0
    const G4 = 0.13819660112501051; // G4 = (5.0-Math.sqrt(5.0))/20.0

    const s = (x + y + z + w) * F4;
    const xs = x + s;
    const ys = y + s;
    const zs = z + s;
    const ws = w + s;
    const i = FASTFLOOR(xs);
    const j = FASTFLOOR(ys);
    const k = FASTFLOOR(zs);
    const l = FASTFLOOR(ws);

    const t = @intToFloat(f64, i +% j +% k +% l) * G4;
    const X0 = @intToFloat(f64, i) - t;
    const Y0 = @intToFloat(f64, j) - t;
    const Z0 = @intToFloat(f64, k) - t;
    const W0 = @intToFloat(f64, l) - t;

    const x0 = x - X0;
    const y0 = y - Y0;
    const z0 = z - Z0;
    const w0 = w - W0;

    const zero: usize = 0; // TODO: remove hack to fix 'comptime_int' must be comptime known.
    const c1 = if (x0 > y0) 32 else zero;
    const c2 = if (x0 > z0) 16 else zero;
    const c3 = if (y0 > z0) 8 else zero;
    const c4 = if (x0 > w0) 4 else zero;
    const c5 = if (y0 > w0) 2 else zero;
    const c6 = if (z0 > w0) 1 else zero;
    const c = c1 + c2 + c3 + c4 + c5 + c6;

    const i1_ = if (simplex[c][0] >= 3) 1 else zero;
    const j1 = if (simplex[c][1] >= 3) 1 else zero;
    const k1 = if (simplex[c][2] >= 3) 1 else zero;
    const l1 = if (simplex[c][3] >= 3) 1 else zero;
    const i2_ = if (simplex[c][0] >= 2) 1 else zero;
    const j2 = if (simplex[c][1] >= 2) 1 else zero;
    const k2 = if (simplex[c][2] >= 2) 1 else zero;
    const l2 = if (simplex[c][3] >= 2) 1 else zero;
    const i3_ = if (simplex[c][0] >= 1) 1 else zero;
    const j3 = if (simplex[c][1] >= 1) 1 else zero;
    const k3 = if (simplex[c][2] >= 1) 1 else zero;
    const l3 = if (simplex[c][3] >= 1) 1 else zero;

    const x1 = x0 - @intToFloat(f64, i1_) + G4;
    const y1 = y0 - @intToFloat(f64, j1) + G4;
    const z1 = z0 - @intToFloat(f64, k1) + G4;
    const w1 = w0 - @intToFloat(f64, l1) + G4;
    const x2 = x0 - @intToFloat(f64, i2_) + 2.0 * G4;
    const y2 = y0 - @intToFloat(f64, j2) + 2.0 * G4;
    const z2 = z0 - @intToFloat(f64, k2) + 2.0 * G4;
    const w2 = w0 - @intToFloat(f64, l2) + 2.0 * G4;
    const x3 = x0 - @intToFloat(f64, i3_) + 3.0 * G4;
    const y3 = y0 - @intToFloat(f64, j3) + 3.0 * G4;
    const z3 = z0 - @intToFloat(f64, k3) + 3.0 * G4;
    const w3 = w0 - @intToFloat(f64, l3) + 3.0 * G4;
    const x4 = x0 - 1.0 + 4.0 * G4;
    const y4 = y0 - 1.0 + 4.0 * G4;
    const z4 = z0 - 1.0 + 4.0 * G4;
    const w4 = w0 - 1.0 + 4.0 * G4;

    const ii = i & 0xff;
    const jj = j & 0xff;
    const kk = k & 0xff;
    const ll = l & 0xff;

    var t0 = 0.6 - x0 * x0 - y0 * y0 - z0 * z0 - w0 * w0;
    const n0 = if (t0 < 0.0) 0.0 else blk: {
        t0 *= t0;
        break :blk t0 * t0 * grad4(perm[ii + perm[jj + perm[kk + perm[ll]]]], x0, y0, z0, w0);
    };

    var t1 = 0.6 - x1 * x1 - y1 * y1 - z1 * z1 - w1 * w1;
    const n1 = if (t1 < 0.0) 0.0 else blk: {
        t1 *= t1;
        break :blk t1 * t1 * grad4(perm[ii + i1_ + perm[jj + j1 + perm[kk + k1 + perm[ll + l1]]]], x1, y1, z1, w1);
    };

    var t2 = 0.6 - x2 * x2 - y2 * y2 - z2 * z2 - w2 * w2;
    const n2 = if (t2 < 0.0) 0.0 else blk: {
        t2 *= t2;
        break :blk t2 * t2 * grad4(perm[ii + i2_ + perm[jj + j2 + perm[kk + k2 + perm[ll + l2]]]], x2, y2, z2, w2);
    };

    var t3 = 0.6 - x3 * x3 - y3 * y3 - z3 * z3 - w3 * w3;
    const n3 = if (t3 < 0.0) 0.0 else blk: {
        t3 *= t3;
        break :blk t3 * t3 * grad4(perm[ii + i3_ + perm[jj + j3 + perm[kk + k3 + perm[ll + l3]]]], x3, y3, z3, w3);
    };

    var t4 = 0.6 - x4 * x4 - y4 * y4 - z4 * z4 - w4 * w4;
    const n4 = if (t4 < 0.0) 0.0 else blk: {
        t4 *= t4;
        break :blk t4 * t4 * grad4(perm[ii + 1 + perm[jj + 1 + perm[kk + 1 + perm[ll + 1]]]], x4, y4, z4, w4);
    };

    return 27.0 * (n0 + n1 + n2 + n3 + n4);
}

fn FASTFLOOR(x: f64) usize {
    return @bitCast(usize, @floatToInt(isize, x + 65535) - 65535);
}

fn grad1(hash: usize, x: f64) f64 {
    const h = hash & 15;
    var grad = @intToFloat(f64, 1 + (h & 7));
    if (h & 8 != 0) {
        grad = -grad;
    }
    return grad * x;
}

fn grad2(hash: usize, x: f64, y: f64) f64 {
    //return switch (hash & 0b111) {
    //    0b000 => y * 2 + x,
    //    0b001 => y * 2 - x,
    //    0b010 => y * -2 + x,
    //    0b011 => y * -2 - x,
    //    0b100 => x * 2 + y,
    //    0b101 => x * 2 - y,
    //    0b110 => x * -2 + y,
    //    0b111 => x * -2 - y,
    //    else => unreachable,
    //};
    const h = hash & 7;
    const w: f64 = 2;
    const u = if (h & 4 == 0) x else y;
    const v = if (h & 4 == 0) y else x;
    const m = if (h & 2 == 0) w else -w;
    const a = if (h & 1 == 0) u else -u;
    return v * m + a;
}

fn grad3(hash: usize, x: f64, y: f64, z: f64) f64 {
    const h = hash & 15;
    const u = if (h < 8) x else y;
    const v = if (h < 4) y else if (h == 12 or h == 14) x else z;
    return (if (h & 1 != 0) -u else u) + (if (h & 2 != 0) -v else v);
}

fn grad4(hash: usize, x: f64, y: f64, z: f64, t: f64) f64 {
    const h = hash & 31;
    const u = if (h < 24) x else y;
    const v = if (h < 16) y else z;
    const w = if (h < 8) z else t;
    return (if (h & 1 != 0) -u else u) + (if (h & 2 != 0) -v else v) + (if (h & 4 != 0) -w else w);
}

const perm = [512]u8{
    151, 160, 137, 91, 90, 15, 131, 13, 201, 95, 96, 53, 194, 233, 7, 225, 140, 36, 103, 30, 69, 142, 8, 99, 37, 240, 21, 10, 23, 190, 6, 148, 247, 120, 234, 75, 0, 26, 197, 62, 94, 252, 219, 203, 117, 35, 11, 32, 57, 177, 33, 88, 237, 149, 56, 87, 174, 20, 125, 136, 171, 168, 68, 175, 74, 165, 71, 134, 139, 48, 27, 166, 77, 146, 158, 231, 83, 111, 229, 122, 60, 211, 133, 230, 220, 105, 92, 41, 55, 46, 245, 40, 244, 102, 143, 54, 65, 25, 63, 161, 1, 216, 80, 73, 209, 76, 132, 187, 208, 89, 18, 169, 200, 196, 135, 130, 116, 188, 159, 86, 164, 100, 109, 198, 173, 186, 3, 64, 52, 217, 226, 250, 124, 123, 5, 202, 38, 147, 118, 126, 255, 82, 85, 212, 207, 206, 59, 227, 47, 16, 58, 17, 182, 189, 28, 42, 223, 183, 170, 213, 119, 248, 152, 2, 44, 154, 163, 70, 221, 153, 101, 155, 167, 43, 172, 9, 129, 22, 39, 253, 19, 98, 108, 110, 79, 113, 224, 232, 178, 185, 112, 104, 218, 246, 97, 228, 251, 34, 242, 193, 238, 210, 144, 12, 191, 179, 162, 241, 81, 51, 145, 235, 249, 14, 239, 107, 49, 192, 214, 31, 181, 199, 106, 157, 184, 84, 204, 176, 115, 121, 50, 45, 127, 4, 150, 254, 138, 236, 205, 93, 222, 114, 67, 29, 24, 72, 243, 141, 128, 195, 78, 66, 215, 61, 156, 180, 151, 160, 137, 91, 90, 15, 131, 13, 201, 95, 96, 53, 194, 233, 7, 225, 140, 36, 103, 30, 69, 142, 8, 99, 37, 240, 21, 10, 23, 190, 6, 148, 247, 120, 234, 75, 0, 26, 197, 62, 94, 252, 219, 203, 117, 35, 11, 32, 57, 177, 33, 88, 237, 149, 56, 87, 174, 20, 125, 136, 171, 168, 68, 175, 74, 165, 71, 134, 139, 48, 27, 166, 77, 146, 158, 231, 83, 111, 229, 122, 60, 211, 133, 230, 220, 105, 92, 41, 55, 46, 245, 40, 244, 102, 143, 54, 65, 25, 63, 161, 1, 216, 80, 73, 209, 76, 132, 187, 208, 89, 18, 169, 200, 196, 135, 130, 116, 188, 159, 86, 164, 100, 109, 198, 173, 186, 3, 64, 52, 217, 226, 250, 124, 123, 5, 202, 38, 147, 118, 126, 255, 82, 85, 212, 207, 206, 59, 227, 47, 16, 58, 17, 182, 189, 28, 42, 223, 183, 170, 213, 119, 248, 152, 2, 44, 154, 163, 70, 221, 153, 101, 155, 167, 43, 172, 9, 129, 22, 39, 253, 19, 98, 108, 110, 79, 113, 224, 232, 178, 185, 112, 104, 218, 246, 97, 228, 251, 34, 242, 193, 238, 210, 144, 12, 191, 179, 162, 241, 81, 51, 145, 235, 249, 14, 239, 107, 49, 192, 214, 31, 181, 199, 106, 157, 184, 84, 204, 176, 115, 121, 50, 45, 127, 4, 150, 254, 138, 236, 205, 93, 222, 114, 67, 29, 24, 72, 243, 141, 128, 195, 78, 66, 215, 61, 156, 180,
};

const simplex = [64][4]u8{
    [4]u8{ 0, 1, 2, 3 }, [4]u8{ 0, 1, 3, 2 }, [4]u8{ 0, 0, 0, 0 }, [4]u8{ 0, 2, 3, 1 }, [4]u8{ 0, 0, 0, 0 }, [4]u8{ 0, 0, 0, 0 }, [4]u8{ 0, 0, 0, 0 }, [4]u8{ 1, 2, 3, 0 },
    [4]u8{ 0, 2, 1, 3 }, [4]u8{ 0, 0, 0, 0 }, [4]u8{ 0, 3, 1, 2 }, [4]u8{ 0, 3, 2, 1 }, [4]u8{ 0, 0, 0, 0 }, [4]u8{ 0, 0, 0, 0 }, [4]u8{ 0, 0, 0, 0 }, [4]u8{ 1, 3, 2, 0 },
    [4]u8{ 0, 0, 0, 0 }, [4]u8{ 0, 0, 0, 0 }, [4]u8{ 0, 0, 0, 0 }, [4]u8{ 0, 0, 0, 0 }, [4]u8{ 0, 0, 0, 0 }, [4]u8{ 0, 0, 0, 0 }, [4]u8{ 0, 0, 0, 0 }, [4]u8{ 0, 0, 0, 0 },
    [4]u8{ 1, 2, 0, 3 }, [4]u8{ 0, 0, 0, 0 }, [4]u8{ 1, 3, 0, 2 }, [4]u8{ 0, 0, 0, 0 }, [4]u8{ 0, 0, 0, 0 }, [4]u8{ 0, 0, 0, 0 }, [4]u8{ 2, 3, 0, 1 }, [4]u8{ 2, 3, 1, 0 },
    [4]u8{ 1, 0, 2, 3 }, [4]u8{ 1, 0, 3, 2 }, [4]u8{ 0, 0, 0, 0 }, [4]u8{ 0, 0, 0, 0 }, [4]u8{ 0, 0, 0, 0 }, [4]u8{ 2, 0, 3, 1 }, [4]u8{ 0, 0, 0, 0 }, [4]u8{ 2, 1, 3, 0 },
    [4]u8{ 0, 0, 0, 0 }, [4]u8{ 0, 0, 0, 0 }, [4]u8{ 0, 0, 0, 0 }, [4]u8{ 0, 0, 0, 0 }, [4]u8{ 0, 0, 0, 0 }, [4]u8{ 0, 0, 0, 0 }, [4]u8{ 0, 0, 0, 0 }, [4]u8{ 0, 0, 0, 0 },
    [4]u8{ 2, 0, 1, 3 }, [4]u8{ 0, 0, 0, 0 }, [4]u8{ 0, 0, 0, 0 }, [4]u8{ 0, 0, 0, 0 }, [4]u8{ 3, 0, 1, 2 }, [4]u8{ 3, 0, 2, 1 }, [4]u8{ 0, 0, 0, 0 }, [4]u8{ 3, 1, 2, 0 },
    [4]u8{ 2, 1, 0, 3 }, [4]u8{ 0, 0, 0, 0 }, [4]u8{ 0, 0, 0, 0 }, [4]u8{ 0, 0, 0, 0 }, [4]u8{ 3, 1, 0, 2 }, [4]u8{ 0, 0, 0, 0 }, [4]u8{ 3, 2, 0, 1 }, [4]u8{ 3, 2, 1, 0 },
};
