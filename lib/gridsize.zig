const std = @import("std");
const math = std.math;

pub fn GridSize(comptime width_: usize, comptime height_: usize) type {
    return struct {
        const GS = @This();

        pub const width = width_;
        pub const height = height_;
        pub const len = width * height;

        pub const widthf = @intToFloat(f64, width);
        pub const heightf = @intToFloat(f64, height);
        pub const lenf = @intToFloat(f64, len);

        pub const xs = @intToFloat(f64, width);
        pub const ys = @intToFloat(f64, height);

        pub const xu = 1.0 / xs;
        pub const yu = 1.0 / ys;

        pub const Cell = struct {
            x: isize,
            y: isize,

            pub fn isInside(self: *const Cell) bool {
                return self.x >= 0 and self.y >= 0 and self.x < width and self.y < height;
            }

            pub fn inside(self: *const Cell) ?InsideCell {
                return if (self.isInside()) InsideCell{ .x = @intCast(usize, self.x), .y = @intCast(usize, self.y) } else null;
            }

            pub fn index(self: *const Cell) ?usize {
                return GS.index(self.x, self.y);
            }

            pub fn checked(self: *const Cell, a: anytype, b: @TypeOf(a)) @TypeOf(a) {
                return if (self.x & 1 == self.y & 1) a else b;
            }
        };

        pub const InsideCell = struct {
            x: usize,
            y: usize,

            pub fn index(self: *const InsideCell) usize {
                return self.y * width + self.x;
            }
        };

        pub fn index(x: anytype, y: anytype) ?usize {
            if (x >= 0 and y >= 0 and @intCast(isize, x) < @intCast(isize, width) and @intCast(isize, y) < @intCast(isize, height)) {
                return @intCast(usize, y) * width + @intCast(usize, x);
            }
            return null;
        }

        pub fn indexToCell(idx: usize) Cell {
            return .{
                .x = @rem(@intCast(isize, idx), @intCast(isize, width)),
                .y = @divTrunc(@intCast(isize, idx), @intCast(isize, width)),
            };
        }

        pub fn cell(x: f64, y: f64) Cell {
            return Cell{
                .x = @floatToInt(isize, math.floor(x * xs)),
                .y = @floatToInt(isize, math.floor(y * ys)),
            };
        }

        pub const pos = Pos.ofF64;

        pub fn cellx(x: f64) f64 {
            return @mod(x * xs, 1);
        }

        pub fn celly(y: f64) f64 {
            return @mod(y * ys, 1);
        }

        pub fn floatIterator() FloatIterator(width, height) {
            return FloatIterator(width, height).init();
        }

        pub fn floatIndexIterator() FloatIndexIterator(width, height) {
            return FloatIndexIterator(width, height).init();
        }

        pub fn intIterator() IntIterator(width, height) {
            return IntIterator(width, height).init();
        }

        pub fn intIndexIterator() IntIndexIterator(width, height) {
            return IntIndexIterator(width, height).init();
        }

        pub fn northIndex(index: usize) ?usize {
            return if (index < width) null else index - width;
        }

        pub fn southIndex(index: usize) ?usize {
            const result = index + width;
            return if (result >= len) null else result;
        }

        pub fn westIndex(index: usize) ?usize {
            const x = @rem(index, width);
            return if (x == 0) null else x - 1;
        }

        pub fn eastIndex(index: usize) ?usize {
            const x = @rem(index, width);
            const result = x + 1;
            return if (result >= width) null else result;
        }

        pub const Pos = struct {
            const Self = @This();

            index: usize,
            x: usize,
            y: usize,

            pub const first = Self{ .index = 0, .x = 0, .y = 0 };
            pub const last = Self{ .index = len - 1, .x = width - 1, .y = height - 1 };

            pub fn ofIndex(index: usize) ?Self {
                return if (index >= len) null else .{
                    .index = index,
                    .x = @rem(index, width),
                    .y = @divTrunc(index, width),
                };
            }

            pub fn ofXy(x: usize, y: usize) ?Self {
                return if (x >= width or y >= height) null else .{
                    .index = y * width + x,
                    .x = x,
                    .y = y,
                };
            }

            pub fn ofF64(x: f64, y: f64) ?Self {
                if (x < 0 or y < 0) {
                    return null;
                } else {
                    const xi = @floatToInt(usize, math.floor(x * xs));
                    const yi = @floatToInt(usize, math.floor(y * ys));
                    return ofXy(xi, yi);
                }
            }

            pub fn cellx(self: Self, x: f64) f64 {
                return (x * xs) - @intToFloat(f64, self.x);
            }

            pub fn celly(self: Self, y: f64) f64 {
                return (y * ys) - @intToFloat(f64, self.y);
            }

            pub fn north(self: Self) ?Self {
                return if (self.y == 0) null else .{
                    .index = self.index - width,
                    .x = self.x,
                    .y = self.y - 1,
                };
            }

            pub fn south(self: Self) ?Self {
                return if (self.y == height - 1) null else .{
                    .index = self.index + width,
                    .x = self.x,
                    .y = self.y + 1,
                };
            }

            pub fn west(self: Self) ?Self {
                return if (self.x == 0) null else .{
                    .index = self.index - 1,
                    .x = self.x - 1,
                    .y = self.y,
                };
            }

            pub fn east(self: Self) ?Self {
                return if (self.x == width - 1) null else .{
                    .index = self.index + 1,
                    .x = self.x + 1,
                    .y = self.y,
                };
            }

            pub fn northwest(self: Self) ?Self {
                return if (self.north()) |p| p.west() else null;
            }

            pub fn northeast(self: Self) ?Self {
                return if (self.north()) |p| p.east() else null;
            }

            pub fn southwest(self: Self) ?Self {
                return if (self.south()) |p| p.west() else null;
            }

            pub fn southeast(self: Self) ?Self {
                return if (self.south()) |p| p.east() else null;
            }

            pub fn neighbors4(self: Self) [4]?Self {
                return [4]?Self{ self.north(), self.west(), self.east(), self.south() };
            }

            pub fn neighbors8(self: Self) [8]?Self {
                return [8]?Self{ self.northwest(), self.north(), self.northeast(), self.west(), self.east(), self.southwest(), self.south(), self.southeast() };
            }

            pub fn neighbors9(self: Self) [9]?Self {
                return [9]?Self{ self.northwest(), self.north(), self.northeast(), self.west(), self, self.east(), self.southwest(), self.south(), self.southeast() };
            }

            pub fn next(self: Self) ?Self {
                return if (self.index == len - 1) null else if (self.x == width - 1) .{
                    .index = self.index + 1,
                    .x = 0,
                    .y = self.y + 1,
                } else .{
                    .index = self.index + 1,
                    .x = self.x + 1,
                    .y = self.y,
                };
            }

            pub fn prev(self: Self) ?Self {
                return if (self.index == 0) null else if (self.x == 0) .{
                    .index = self.index - 1,
                    .x = self.width - 1,
                    .y = self.y - 1,
                } else .{
                    .index = self.index - 1,
                    .x = self.x - 1,
                    .y = self.y,
                };
            }
        };
    };
}

pub fn FloatIndexIterator(comptime width: usize, comptime height: usize) type {
    return struct {
        const Self = @This();

        floatIt: FloatIterator(width, height),
        index: usize,

        pub fn init() Self {
            return Self{
                .floatIt = FloatIterator(width, height).init(),
                .index = 0,
            };
        }

        pub fn next(self: *Self) ?Cell {
            if (self.floatIt.next()) |cell| {
                var result = Cell{
                    .index = self.index,
                    .x = cell.x,
                    .y = cell.y,
                };

                self.index += 1;
                return result;
            }
            return null;
        }

        pub const Cell = struct {
            index: usize,
            x: f64,
            y: f64,
        };
    };
}

pub fn FloatIterator(comptime width: usize, comptime height: usize) type {
    const wd = 1 / @intToFloat(f64, width);
    const hd = 1 / @intToFloat(f64, height);
    return struct {
        const Self = @This();

        intIt: IntIterator(width, height),
        yf: f64,

        pub fn init() Self {
            return Self{
                .intIt = IntIterator(width, height).init(),
                .yf = 0,
            };
        }

        pub fn next(self: *Self) ?Cell {
            if (self.intIt.next()) |cell| {
                if (cell.x == 0) {
                    self.yf = @intToFloat(f64, cell.y) * hd;
                }

                return Cell{
                    .x = @intToFloat(f64, cell.x) * wd,
                    .y = self.yf,
                };
            } else {
                return null;
            }
        }

        pub fn skipRows(self: *Self, rows: usize) void {
            self.intIt.skipRows(rows);
        }

        pub const Cell = struct {
            x: f64,
            y: f64,
        };
    };
}

pub fn IntIterator(comptime width: usize, comptime height: usize) type {
    return struct {
        const Self = @This();

        x: usize,
        y: usize,

        pub fn init() Self {
            return Self{
                .x = 0,
                .y = 0,
            };
        }

        pub fn next(self: *Self) ?Cell {
            if (self.y >= height) {
                return null;
            }

            var result = Cell{
                .x = self.x,
                .y = self.y,
            };

            self.x += 1;
            if (self.x >= width) {
                self.x = 0;
                self.y += 1;
            }
            return result;
        }

        pub fn skipRows(self: *Self, rows: usize) void {
            self.y += rows;
        }

        pub const Cell = struct {
            x: usize = 0,
            y: usize = 0,
        };
    };
}

pub fn IntIndexIterator(comptime width: usize, comptime height: usize) type {
    return struct {
        const Self = @This();

        x: usize,
        y: usize,
        index: usize,

        pub fn init() Self {
            return Self{
                .x = 0,
                .y = 0,
                .index = 0,
            };
        }

        pub fn next(self: *Self) ?Cell {
            if (self.y >= height) {
                return null;
            }

            var result = Cell{
                .index = self.index,
                .x = self.x,
                .y = self.y,
            };

            self.index += 1;
            self.x += 1;
            if (self.x >= width) {
                self.x = 0;
                self.y += 1;
            }
            return result;
        }

        pub const Cell = struct {
            index: usize,
            x: usize,
            y: usize,
        };
    };
}
