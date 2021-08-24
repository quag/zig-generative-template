pub const Resolutions = struct {
    pub const Instagram = struct {
        pub const square = Res.init(1080, 1080);
        pub const portrait = AspectRatio.init(8, 10).shortSide(1080).portrait();
        pub const landscape = AspectRatio.init(100, 191).longSide(1080);
    };
    pub const Prints = struct {
        pub const _24x36 = Res.init(24, 36).scale(600);
        pub const _24x30 = Res.init(24, 30).scale(600);
        pub const _20x30 = Res.init(20, 30).scale(600);
        pub const _20x24 = Res.init(20, 24).scale(600);
        pub const _16x20 = Res.init(16, 20).scale(600);
        pub const _18x24 = Res.init(18, 24).scale(600);
        pub const _11x14 = Res.init(11, 14).scale(600);
        pub const _10x20 = Res.init(10, 20).scale(600);
        pub const _10x13 = Res.init(10, 13).scale(600);
        pub const _8x10 = Res.init(8, 10).scale(600);
        pub const _5x7 = Res.init(5, 7).scale(600);
        pub const _4x6 = Res.init(4, 6).scale(600);
        pub const _4x5_3 = Res.init(40, 53).scale(60);
        pub const _3x5 = Res.init(3, 5).scale(600);

        pub const _12x36 = Res.init(12, 36).scale(600);
        pub const _8x24 = Res.init(8, 24).scale(600);
        pub const _5x15 = Res.init(5, 15).scale(600);

        pub const _30x30 = Res.square(30).scale(600);
        pub const _20x20 = Res.square(20).scale(600);
        pub const _16x16 = Res.square(16).scale(600);
        pub const _12x12 = Res.square(12).scale(600);
        pub const _10x10 = Res.square(10).scale(600);
        pub const _8x8 = Res.square(8).scale(600);
        pub const _6x6 = Res.square(6).scale(600);
        pub const _5x5 = Res.square(5).scale(600);
        pub const _4x4 = Res.square(4).scale(600);
    };
    pub const Wallpapers = struct {
        pub const _4k = AspectRatio.init(16, 9).shortSide(2160);
        pub const square_2160 = Res.square(2160);
        pub const iosParallax = Res.square(2662);
        pub const wide_1440 = Res.init(3440, 1440);
        pub const macbook_13 = AspectRatio.init(8, 5).shortSide(1600);
    };
    pub const Screen = struct {
        pub const _240p = Res.init(320, 240);
        pub const _480p = Res.init(640, 480);
        pub const _720p = Res.init(1280, 720);
        pub const _1080p = Res.init(1920, 1080);
        pub const _1440p = Res.init(2560, 1440);
        pub const _2160p = Res.init(3840, 2160);
        pub const _4320p = Res.init(7680, 4320);

        pub const ldtv = _240p;
        pub const hdtv = _720p;
        pub const qhd = _1440p;
        pub const _4k = _2160p;
        pub const _8k = _4320p;

        pub const vga = Res.init(640, 480);
        pub const svga = Res.init(800, 600);
    };
};

pub const AspectRatio = struct {
    small: usize = 1,
    big: usize = 1,

    const Self = @This();
    pub fn init(a: usize, b: usize) Self {
        return if (a < b) .{ .small = a, .big = b } else .{ .small = b, .big = a };
    }

    pub fn square() Self {
        return .{};
    }

    pub fn shortSide(self: Self, size: usize) Res {
        return Res{
            .width = size * self.big / self.small,
            .height = size,
        };
    }

    pub fn longSide(self: Self, size: usize) Res {
        return Res{
            .width = size,
            .height = size * self.small / self.big,
        };
    }
};

pub const Res = struct {
    width: usize,
    height: usize,

    const Self = @This();
    pub fn init(width: usize, height: usize) Self {
        return .{ .width = width, .height = height };
    }

    pub fn square(size: usize) Self {
        return init(size, size);
    }

    pub fn limitPixels(self: Self, limit: usize) Self {
        var count = self.width * self.height;
        var i: u6 = 0;
        while (count > limit) {
            count >>= 2;
            i += 1;
        }
        return .{
            .width = self.width >> i,
            .height = self.height >> i,
        };
    }

    pub fn scale(self: Self, factor: usize) Self {
        return init(self.width * factor, self.height * factor);
    }

    pub fn portrait(self: Self) Self {
        return if (self.height >= self.width) self else init(self.height, self.width);
    }

    pub fn landscape(self: Self) Self {
        return if (self.width >= self.height) self else init(self.height, self.width);
    }
};
