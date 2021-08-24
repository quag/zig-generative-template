const Res = @import("resolutions.zig").Res;

pub const ShaderConfig = struct {
    res: Res,
    frameNo: usize,
    time: f64,
};
