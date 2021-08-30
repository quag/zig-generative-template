const std = @import("std");
const unitbounds = @import("unitbounds.zig");

const Allocator = std.mem.Allocator;

pub fn Screen(comptime Cell: type) type {
    return struct {
        const Self = @This();

        allocator: *Allocator,
        cells: []Cell,

        width: usize,
        height: usize,
        ub: unitbounds.Pos01ToIndex,

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
                .ub = unitbounds.Pos01ToIndex.forCenter(width, height, 0),
            };
        }

        pub fn deinit(self: *const Self) void {
            self.allocator.free(self.cells);
        }

        pub fn indexRef(self: *Self, i: ?usize) ?*Cell {
            if (i) |j| {
                return &self.cells[j];
            }
            return null;
        }

        pub fn getIndex(self: *const Self, i: ?usize) ?Cell {
            if (i) |j| {
                return self.cells[j];
            }
            return null;
        }

        pub fn ref(self: *Self, x: f64, y: f64) ?*Cell {
            return self.indexRef(self.ub.index(x, y));
        }

        pub fn get(self: *const Self, x: f64, y: f64) ?Cell {
            return self.getIndex(self.ub.index(x, y));
        }

        pub fn refi(self: *Self, xi: isize, yi: isize) ?*Cell {
            return self.indexRef(self.ub.res.indexi(xi, yi));
        }

        pub fn geti(self: *const Self, xi: isize, yi: isize) ?Cell {
            return self.getIndex(self.ub.res.indexi(xi, yi));
        }

        pub fn getOff(self: *const Self, x: f64, y: f64, xo: isize, yo: isize) ?Cell {
            return self.getIndex(self.ub.indexOff(x, y, xo, yo));
        }

        pub fn refOff(self: *Self, x: f64, y: f64, xo: isize, yo: isize) ?*Cell {
            return self.indexRef(self.ub.indexOff(x, y, xo, yo));
        }

        pub const Offset = unitbounds.Pos01ToIndex.Offset;

        pub fn getOffsets(self: *const Self, x: f64, y: f64, comptime n: usize, comptime offsets: [n]Offset) [n]?Cell {
            var result = [_]?Cell{null} ** n;
            for (self.ub.indexOffsets(x, y, n, offsets)) |index, i| {
                result[i] = self.getIndex(index);
            }
            return result;
        }

        pub fn refOffsets(self: *const Self, x: f64, y: f64, comptime n: usize, comptime offsets: [n]Offset) [n]?*Cell {
            var result = [_]?Cell{null} ** n;
            for (self.ub.indexOffsets(x, y, n, offsets)) |index, i| {
                result[i] = self.indexRef(index);
            }
            return result;
        }

        pub fn neighbors4(self: *const Self, x: f64, y: f64) [4]?Cell {
            return self.getOffsets(x, y, 4, unitbounds.Pos01ToIndex.neighbors4);
        }

        pub fn neighbors5(self: *const Self, x: f64, y: f64) [5]?Cell {
            return self.getOffsets(x, y, 5, unitbounds.Pos01ToIndex.neighbors5);
        }

        pub fn neighbors8(self: *const Self, x: f64, y: f64) [8]?Cell {
            return self.getOffsets(x, y, 8, unitbounds.Pos01ToIndex.neighbors8);
        }

        pub fn neighbors9(self: *const Self, x: f64, y: f64) [9]?Cell {
            return self.getOffsets(x, y, 9, unitbounds.Pos01ToIndex.neighbors9);
        }
    };
}
