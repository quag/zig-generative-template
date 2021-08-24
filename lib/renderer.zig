const std = @import("std");
const warn = std.debug.warn;
const fmt = std.fmt;

const Allocator = std.mem.Allocator;

const pngShader = @import("pngShader.zig");
const SsaaShader = @import("ssaashader.zig").SsaaShader;
pub const ShaderConfig = @import("shaderconfig.zig").ShaderConfig;

const resolutions = @import("resolutions.zig");
pub const Resolutions = resolutions.Resolutions;
const Res = resolutions.Res;

pub fn render(comptime config: RenderConfig) !void {
    const simpleConfig = comptime config.simpleConfig();
    try simpleConfig.render();
}

pub const RenderConfig = struct {
    Shader: type,
    res: Res,
    ssaa: usize = 3,
    frames: usize = 1,
    memoryLimitMiB: usize = 64,
    preview: bool = false,
    preview_samples: usize,
    preview_ssaa: usize = 1,

    path: []const u8,
    frameTemplate: []const u8,

    const Self = @This();
    fn simpleConfig(comptime self: Self) SimpleConfig {
        const ssaa = if (self.preview) self.preview_ssaa else self.ssaa;
        return .{
            .Shader = self.Shader,
            .res = if (self.preview) self.res.limitPixels(self.preview_samples / ssaa) else self.res,
            .ssaa = ssaa,
            .frames = self.frames,
            .memoryLimitMiB = self.memoryLimitMiB,
            .path = self.path,
            .frameTemplate = self.frameTemplate,
        };
    }
};

pub const SimpleConfig = struct {
    Shader: type,
    res: Res,
    ssaa: usize,
    frames: usize,
    memoryLimitMiB: usize,
    path: []const u8,
    frameTemplate: []const u8,

    const Self = @This();
    fn render(comptime self: Self) !void {
        warn("▶ {}×{}×{}×{}\n", .{ self.res.width, self.res.height, self.ssaa, self.frames });
        defer warn("■\n", .{});
        errdefer warn("!", .{});

        var frameNo: usize = 0;
        while (frameNo < self.frames) : (frameNo += 1) {
            var gpa: std.heap.GeneralPurposeAllocator(.{ .enable_memory_limit = true, .verbose_log = false }) = .{};
            defer _ = gpa.deinit();
            gpa.setRequestedMemoryLimit(self.memoryLimitMiB * 1024 * 1024);
            const allocator = &gpa.allocator;

            const fileName: [:0]u8 = if (self.frames == 1) try fmt.allocPrintZ(allocator, self.path, .{}) else try fmt.allocPrintZ(allocator, self.frameTemplate, .{frameNo});
            defer allocator.free(fileName);

            warn("{s}\n", .{fileName});

            var timer = try std.time.Timer.start();

            const shaderConfig = ShaderConfig{
                .res = comptime self.res.scale(self.ssaa),
                .frameNo = frameNo,
                .time = @intToFloat(f64, frameNo) / @intToFloat(f64, self.frames),
            };

            const shaderContext = try SsaaShader(@intToFloat(f64, self.res.width), @intToFloat(f64, self.res.height), self.ssaa, self.Shader).init(allocator, shaderConfig);
            defer shaderContext.deinit(allocator);
            const shaderFn = @TypeOf(shaderContext).shade;

            warn(" init: {}ms\n", .{(timer.lap() * std.time.ms_per_s) / std.time.ns_per_s});

            try pngShader.fileRender(fileName, &shaderContext, shaderFn, self.res.width, self.res.height, allocator, gpa);

            warn(" render: {}ms\n", .{(timer.lap() * std.time.ms_per_s) / std.time.ns_per_s});
        }
    }
};
