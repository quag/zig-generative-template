const std = @import("std");

const Allocator = std.mem.Allocator;

pub fn Screen(comptime Cell: type) type {
    return struct {
        const Self = @This();

        allocator: *Allocator,
        cells: []Cell,

        width: usize,
        height: usize,

        pub fn init(allocator: *Allocator, width: usize, height: usize, default: Cell) !Self {
            const count = width * height;
            var cells = try allocator.alloc(Cell, count);
            errdefer allocator.free(cells);

            for (cells) |*cell| {
                cell.* = default;
            }

            return Self{
                .allocator = allocator,
                .cells = cells,
                .width = width,
                .height = height,
            };
        }

        pub fn deinit(self: *const Self) void {
            self.allocator.free(self.cells);
        }

        fn round(x: f64, limit: usize, skew: f64) isize {
            return @floatToInt(isize, x * @intToFloat(f64, limit) + skew);
        }

        pub fn xIndexSkew(self: *const Self, x: f64, skew: f64) isize {
            return round(x, self.width, skew);
        }

        pub fn yIndexSkew(self: *const Self, y: f64, skew: f64) isize {
            return round(y, self.height, skew);
        }

        pub fn xIndex(self: *const Self, x: f64) isize {
            return self.xIndexSkew(x, 0);
        }

        pub fn yIndex(self: *const Self, y: f64) isize {
            return self.yIndexSkew(y, 0);
        }

        pub fn indexi(self: *const Self, xi: isize, yi: isize) ?usize {
            if (xi >= 0 and yi >= 0 and xi < self.width and yi < self.height) {
                const xu = @intCast(usize, xi);
                const yu = @intCast(usize, yi);
                return yu * self.width + xu;
            }
            return null;
        }

        pub fn index(self: *const Self, x: f64, y: f64) ?usize {
            return self.indexi(self.xIndex(x), self.yIndex(y));
        }

        fn indexRef(self: *Self, i: ?usize) ?*Cell {
            if (i) |j| {
                return &self.cells[j];
            }
            return null;
        }

        fn getIndex(self: *const Self, i: ?usize) ?Cell {
            if (i) |j| {
                return self.cells[j];
            }
            return null;
        }

        pub fn ref(self: *Self, x: f64, y: f64) ?*Cell {
            return self.indexRef(self.index(x, y));
        }

        pub fn get(self: *const Self, x: f64, y: f64) ?Cell {
            return self.getIndex(self.index(x, y));
        }

        pub fn refSkew(self: *Self, x: f64, y: f64, skew: f64) ?*Cell {
            return self.indexRef(self.indexi(self.xIndexSkew(x, skew), self.yIndexSkew(y, skew)));
        }
    };
}
