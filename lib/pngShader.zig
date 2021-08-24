const std = @import("std");
const Allocator = std.mem.Allocator;

const c = @cImport({
    @cInclude("stb_image_write.h");
});

pub fn fileRender(outPath: [:0]const u8, shaderContext: anytype, shaderFn: anytype, width: comptime_int, height: comptime_int, allocator: *Allocator, gpa: anytype) !void {
    var timer = try std.time.Timer.start();

    const bufSize = width * height * 3;
    var allocBuf = try allocator.alloc(u8, bufSize);
    defer allocator.free(allocBuf);
    var buf = @ptrCast([*c]u8, allocBuf);

    const rowStride = width * 3;

    const ThreadContext = RenderThreadContext(@TypeOf(shaderContext), @TypeOf(shaderFn), width, height);

    const cpuCount = try std.Thread.cpuCount();
    var threadContexts = try allocator.alloc(ThreadContext, cpuCount);
    defer allocator.free(threadContexts);
    for (threadContexts) |*threadContext, index| {
        const partition = Partition.init(height, threadContexts.len, index);

        threadContext.* = ThreadContext{
            .partition = partition,
            .buf = buf[partition.x0 * rowStride .. partition.x1 * rowStride],
            .shaderContext = shaderContext,
            .shaderFn = shaderFn,
        };
    }

    var threads = try allocator.alloc(?*std.Thread, threadContexts.len);
    defer allocator.free(threads);
    for (threads) |*thread| {
        thread.* = null;
    }

    var fail = false;
    {
        defer {
            for (threads) |threadOpt, threadIndex| {
                if (threadOpt) |thread| {
                    thread.wait();
                    if (threadContexts[threadIndex].failed) {
                        fail = true;
                    }
                } else {
                    fail = true;
                }
            }
        }

        for (threads) |*threadOpt, index| {
            threadOpt.* = try std.Thread.spawn(ThreadContext.start, &threadContexts[index]);
        }
    }
    if (fail) {
        return error.ShadingThreadFailed;
    }

    const t1 = timer.lap();

    var result = c.stbi_write_png(outPath, width, height, 3, buf, rowStride);
    if (result == 0) {
        return error.stbi_write_png_failed;
    }

    const t2 = timer.lap();

    warnTime(t1, "shading");
    warnTime(t2, "png");
    std.debug.warn(" memory: {d:.1}MiB\n", .{@intToFloat(f64, gpa.total_requested_bytes) / 1024 / 1024});
}

fn warnTime(time: u64, name: []const u8) void {
    std.debug.warn(" {s}: {any}ms\n", .{ name, time * std.time.ms_per_s / std.time.ns_per_s });
}

const Partition = struct {
    const Self = @This();

    x0: usize,
    x1: usize,

    pub fn init(n: usize, partitions: usize, index: usize) Self {
        return .{
            .x0 = n * index / partitions,
            .x1 = n * (index + 1) / partitions,
        };
    }
};

const RowPartitionIterator = struct {
    const Self = @This();

    xy: Xy,
    limit: Xy,

    pub fn init(width: usize, height: usize, rowRange: Partition) Self {
        return Self{
            .xy = .{ .x = 0, .y = rowRange.x0 },
            .limit = .{ .x = width, .y = rowRange.x1 },
        };
    }

    pub fn next(self: *Self) ?Xy {
        if (self.xy.y >= self.limit.y) {
            return null;
        }

        var result = self.xy;

        self.xy.x += 1;
        if (self.xy.x >= self.limit.x) {
            self.xy.x = 0;
            self.xy.y += 1;
        }

        return result;
    }

    pub const Xy = struct {
        x: usize,
        y: usize,
    };
};

fn RenderThreadContext(comptime ShaderContext: type, comptime ShaderFn: type, width: comptime_int, height: comptime_int) type {
    return struct {
        const Self = @This();

        partition: Partition,
        buf: []u8,
        shaderContext: ShaderContext,
        shaderFn: ShaderFn,
        failed: bool = false,

        fn start(self: *Self) void {
            self.startCanError() catch |err| {
                self.failed = true;
                std.debug.warn("error: {}\n", .{@errorName(err)});
                if (@errorReturnTrace()) |trace| {
                    std.debug.dumpStackTrace(trace.*);
                }
            };
        }

        fn startCanError(self: *Self) !void {
            var rest: []u8 = self.buf;
            var it = RowPartitionIterator.init(width, height, self.partition);
            while (it.next()) |xy| {
                const pixel = self.shaderFn(self.shaderContext, xy.x, xy.y);
                rest[0] = pixel.r;
                rest[1] = pixel.g;
                rest[2] = pixel.b;
                rest = rest[3..];
            }
        }
    };
}
