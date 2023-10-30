const std = @import("std");
const builtin = @import("builtin");

const mem = std.mem;
const heap = std.heap;
const assert = std.debug.assert;

comptime {
  const endianness = builtin.cpu.arch.endian();
  if (.Big == endianness) @compileError("big endian cpu is not supported");
}

pub const RGBA = packed struct { r: u8, g: u8, b: u8, a: u8 = 255 };

pub const framebuffer = struct {
  _: ?[]RGBA,
  width: usize,
  height: usize,

  pub fn len(self: framebuffer) usize { return 4 * self.width * self.height; }
  pub fn ptr(self: framebuffer, comptime T: type) [*]align(4) T { return @ptrCast([*]align(4) T, self._.?.ptr); }
  pub fn slice(self: framebuffer, comptime T: type) []align(4) T { return std.mem.bytesAsSlice(T, std.mem.sliceAsBytes(self._.?)); }
  pub fn clone(fb: framebuffer, allocator: mem.Allocator) !framebuffer { return .{ .width = fb.width, .height = fb.height, ._ = try allocator.dupe(RGBA, fb._.?) }; }

  pub fn init(width: usize, height: usize, allocator: mem.Allocator) !framebuffer {
    return .{
      .width = width,
      .height = height,
      ._ = if (0 == width * height) null else try allocator.alloc(RGBA, width * height),
    };
  }

  pub fn deinit(fb: *framebuffer, allocator: mem.Allocator) void {
    defer {
      fb._ = null;
      fb.width = 0;
      fb.height = 0;
    }

    if (fb._) |s| allocator.free(s);
  }

  pub fn fill(self: framebuffer, color: RGBA) void {
    const width = self.width;
    const height = self.height;
    const c = @bitCast(u32, color);
    for (self.ptr(u32)[0..width]) |*cc| cc.* = c;

    var y: usize = 1;
    const p = self.slice(u8);
    while (y < height) : (y += 1) @memcpy(p[(y * width)..], p[0..width]);
  }

  pub fn flip(self: framebuffer, direction: enum { vertical, horizontal }) void {
    var u = self.slice(u32);
    const width = self.width;
    const height = self.height;

    switch (direction) {
      .vertical => {
        var y: usize = 0;
        const mid = height / 2;
        const aligned = width & ~@as(usize, 0x07);

        while (y < mid) : (y += 1) {
          var x: usize = 0;
          const upper = u[(y * width)..][0..width];
          const lower = u[(width * (height - 1 - y))..][0..width];

          defer {
            while (x < width) : (x += 1) {
              @call(.never_inline, mem.swap, .{u32, &upper[x], &lower[x]});
            }
          }

          while (x < aligned) : (x += 8) {
            const upper_8 = upper[x..][0..8];
            const lower_8 = lower[x..][0..8];
            mem.swap([8]u32, upper_8, lower_8);
          }
        }
      },

      .horizontal => {
        const mid = width / 2;
        const aligned = mid & ~@as(usize, 0x07);

        while (0 < u.len) : (u = u[width..]) {
          var x: usize = 0;

          defer {
            while (x < mid) : (x += 1) {
              @call(.never_inline, mem.swap, .{u32, &u[x], &u[width - x - 1]});
            }
          }

          while (x < aligned) : (x += 8) {
            const upper = u[x..][0..8];
            const lower = u[(width - x - 8)..][0..8];
            const reverse: @Vector(8, i32) = .{7, 6, 5, 4, 3, 2, 1, 0};
            const upper_rev = @shuffle(u32, upper.*, upper.*, reverse);
            const lower_rev = @shuffle(u32, lower.*, lower.*, reverse);

            upper.* = lower_rev;
            lower.* = upper_rev;
          }
        }
      },
    }
  }

  pub fn invert(fb: framebuffer, sigma: f32) void {
    var offset: usize = 0;
    const s = fb.slice(u32);
    @setFloatMode(.Optimized);
    const aligned = s.len & ~@as(usize, 0x07);
    const fsigma = std.math.clamp(sigma, 0.0, 1.0);
    const isigma = std.math.clamp(1.0 - fsigma, 0.0, 1.0);

    if (0.0 == fsigma) {}

    else if (1.0 == fsigma) {
      defer { for (s[aligned..]) |*c| c.* ^= 0x00ffffff; }
      while (offset < aligned) : (offset += 8) s[offset..][0..8].* ^= @splat(8, @as(u32, 0x00ffffff));
    }

    else {
      defer {
        for (s[aligned..]) |*c| {
          const rr = @intToFloat(f32, c.* & 0xff);
          const gg = @intToFloat(f32, (c.* >> 8) & 0xff);
          const bb = @intToFloat(f32, (c.* >> 16) & 0xff);

          const r = @floatToInt(u32, rr * isigma + fsigma * (255.0 - rr));
          const g = @floatToInt(u32, gg * isigma + fsigma * (255.0 - gg));
          const b = @floatToInt(u32, bb * isigma + fsigma * (255.0 - bb));

          c.* = r | (g << 8) | (b << 16) | (c.* >> 24 << 24);
        }
      }

      while (offset < aligned) : (offset += 8) {
        const c = s[offset..][0..8];
        const cv: @Vector(8, u32) = c.*;

        const rch = cv & @splat(8, @as(u32, 0xff));
        const gch = (cv >> @splat(8, @as(u5, 8))) & @splat(8, @as(u32, 0xff));
        const bch = (cv >> @splat(8, @as(u5, 16))) & @splat(8, @as(u32, 0xff));

        const rf = [8]f32 {
          @intToFloat(f32, rch[0]), @intToFloat(f32, rch[1]), @intToFloat(f32, rch[2]), @intToFloat(f32, rch[3]),
          @intToFloat(f32, rch[4]), @intToFloat(f32, rch[5]), @intToFloat(f32, rch[6]), @intToFloat(f32, rch[7]),
        };

        const gf = [8]f32 {
          @intToFloat(f32, gch[0]), @intToFloat(f32, gch[1]), @intToFloat(f32, gch[2]), @intToFloat(f32, gch[3]),
          @intToFloat(f32, gch[4]), @intToFloat(f32, gch[5]), @intToFloat(f32, gch[6]), @intToFloat(f32, gch[7]),
        };

        const bf = [8]f32 {
          @intToFloat(f32, bch[0]), @intToFloat(f32, bch[1]), @intToFloat(f32, bch[2]), @intToFloat(f32, bch[3]),
          @intToFloat(f32, bch[4]), @intToFloat(f32, bch[5]), @intToFloat(f32, bch[6]), @intToFloat(f32, bch[7]),
        };

        const rr = rf * @splat(8, isigma) + @splat(8, fsigma) * (@splat(8, @as(f32, 255)) - rf);
        const gg = gf * @splat(8, isigma) + @splat(8, fsigma) * (@splat(8, @as(f32, 255)) - gf);
        const bb = bf * @splat(8, isigma) + @splat(8, fsigma) * (@splat(8, @as(f32, 255)) - bf);

        const r = [8]u32 {
          @floatToInt(u32, rr[0]), @floatToInt(u32, rr[1]), @floatToInt(u32, rr[2]), @floatToInt(u32, rr[3]),
          @floatToInt(u32, rr[4]), @floatToInt(u32, rr[5]), @floatToInt(u32, rr[6]), @floatToInt(u32, rr[7]),
        };

        const g: @Vector(8, u32) = [8]u32 {
          @floatToInt(u32, gg[0]), @floatToInt(u32, gg[1]), @floatToInt(u32, gg[2]), @floatToInt(u32, gg[3]),
          @floatToInt(u32, gg[4]), @floatToInt(u32, gg[5]), @floatToInt(u32, gg[6]), @floatToInt(u32, gg[7]),
        };

        const b: @Vector(8, u32) = [8]u32 {
          @floatToInt(u32, bb[0]), @floatToInt(u32, bb[1]), @floatToInt(u32, bb[2]), @floatToInt(u32, bb[3]),
          @floatToInt(u32, bb[4]), @floatToInt(u32, bb[5]), @floatToInt(u32, bb[6]), @floatToInt(u32, bb[7]),
        };

        c.* = r | (g << @splat(8, @as(u5, 8))) | (b << @splat(8, @as(u5, 16))) | (cv >> @splat(8, @as(u5, 24)) << @splat(8, @as(u5, 24)));
      }
    }
  }

  pub fn linear(fb: framebuffer, mul: [4]f32, add: [4]i32) void {
    var offset: usize = 0;
    const s = fb.slice(u32);
    @setFloatMode(.Optimized);
    const aligned = s.len & ~@as(usize, 0x07);

    defer {
      for (s[aligned..]) |*c| {
        const r = @intCast(u32, std.math.clamp(add[0] + @floatToInt(i32, mul[0] * @intToFloat(f32, c.* & 0xff)), 0, 255));
        const g = @intCast(u32, std.math.clamp(add[1] + @floatToInt(i32, mul[1] * @intToFloat(f32, (c.* >> 8) & 0xff)), 0, 255));
        const b = @intCast(u32, std.math.clamp(add[2] + @floatToInt(i32, mul[2] * @intToFloat(f32, (c.* >> 16) & 0xff)), 0, 255));
        const a = @intCast(u32, std.math.clamp(add[3] + @floatToInt(i32, mul[3] * @intToFloat(f32, (c.* >> 24) & 0xff)), 0, 255));

        c.* = r | (g << 8) | (b << 16) | (a << 24);
      }
    }

    while (offset < aligned) : (offset += 8) {
      const c = s[offset..][0..8];
      const cv: @Vector(8, u32) = c.*;
      const min: @Vector(8, i32) = [_]i32 {0} ** 8;
      const max: @Vector(8, i32) = [_]i32 {255} ** 8;

      var rch = cv & @splat(8, @as(u32, 0xff));
      var gch = (cv >> @splat(8, @as(u5, 8))) & @splat(8, @as(u32, 0xff));
      var bch = (cv >> @splat(8, @as(u5, 16))) & @splat(8, @as(u32, 0xff));
      var ach = (cv >> @splat(8, @as(u5, 24))) & @splat(8, @as(u32, 0xff));

      const rf = @splat(8, mul[0]) * [8]f32 {
        @intToFloat(f32, rch[0]), @intToFloat(f32, rch[1]), @intToFloat(f32, rch[2]), @intToFloat(f32, rch[3]),
        @intToFloat(f32, rch[4]), @intToFloat(f32, rch[5]), @intToFloat(f32, rch[6]), @intToFloat(f32, rch[7]),
      };

      const gf = @splat(8, mul[1]) * [8]f32 {
        @intToFloat(f32, gch[0]), @intToFloat(f32, gch[1]), @intToFloat(f32, gch[2]), @intToFloat(f32, gch[3]),
        @intToFloat(f32, gch[4]), @intToFloat(f32, gch[5]), @intToFloat(f32, gch[6]), @intToFloat(f32, gch[7]),
      };

      const bf = @splat(8, mul[2]) * [8]f32 {
        @intToFloat(f32, bch[0]), @intToFloat(f32, bch[1]), @intToFloat(f32, bch[2]), @intToFloat(f32, bch[3]),
        @intToFloat(f32, bch[4]), @intToFloat(f32, bch[5]), @intToFloat(f32, bch[6]), @intToFloat(f32, bch[7]),
      };

      const af = @splat(8, mul[3]) * [8]f32 {
        @intToFloat(f32, ach[0]), @intToFloat(f32, ach[1]), @intToFloat(f32, ach[2]), @intToFloat(f32, ach[3]),
        @intToFloat(f32, ach[4]), @intToFloat(f32, ach[5]), @intToFloat(f32, ach[6]), @intToFloat(f32, ach[7]),
      };

      const r = @intCast(@Vector(8, u32), @min(max, @max(min, @splat(8, add[0]) + [8]i32 {
        @floatToInt(i32, rf[0]), @floatToInt(i32, rf[1]), @floatToInt(i32, rf[2]), @floatToInt(i32, rf[3]),
        @floatToInt(i32, rf[4]), @floatToInt(i32, rf[5]), @floatToInt(i32, rf[6]), @floatToInt(i32, rf[7]),
      })));

      const g = @intCast(@Vector(8, u32), @min(max, @max(min, @splat(8, add[1]) + [8]i32 {
        @floatToInt(i32, gf[0]), @floatToInt(i32, gf[1]), @floatToInt(i32, gf[2]), @floatToInt(i32, gf[3]),
        @floatToInt(i32, gf[4]), @floatToInt(i32, gf[5]), @floatToInt(i32, gf[6]), @floatToInt(i32, gf[7]),
      })));

      const b = @intCast(@Vector(8, u32), @min(max, @max(min, @splat(8, add[2]) + [8]i32 {
        @floatToInt(i32, bf[0]), @floatToInt(i32, bf[1]), @floatToInt(i32, bf[2]), @floatToInt(i32, bf[3]),
        @floatToInt(i32, bf[4]), @floatToInt(i32, bf[5]), @floatToInt(i32, bf[6]), @floatToInt(i32, bf[7]),
      })));

      const a = @intCast(@Vector(8, u32), @min(max, @max(min, @splat(8, add[3]) + [8]i32 {
        @floatToInt(i32, af[0]), @floatToInt(i32, af[1]), @floatToInt(i32, af[2]), @floatToInt(i32, af[3]),
        @floatToInt(i32, af[4]), @floatToInt(i32, af[5]), @floatToInt(i32, af[6]), @floatToInt(i32, af[7]),
      })));

      c.* = r | (g << @splat(8, @as(u5, 8))) | (b << @splat(8, @as(u5, 16))) | (a << @splat(8, @as(u5, 24)));
    }
  }

  pub fn resize(fb: framebuffer, kernel: enum { box, nearest, hamming, bilinear }, width: usize, height: usize, allocator: mem.Allocator) !framebuffer {
    @setFloatMode(.Optimized);
    if (0 == width or 0 == height) return try framebuffer.init(0, 0, allocator);
    if (width == fb.width and height == fb.height) return try fb.clone(allocator);

    assert(0 != width);
    assert(0 != height);
    var stack = heap.stackFallback(65536, allocator);
    var nfb = try framebuffer.init(width, height, allocator);

    errdefer nfb.deinit(allocator);
    var arena = heap.ArenaAllocator.init(stack.get());

    const S = arena.allocator();
    defer _ = arena.reset(.free_all);

    switch (kernel) {
      .nearest => {
        const s = nfb.slice(u32);
        const os = fb.slice(u32);
        const xt = try S.alloc(usize, width);
        const xw = @intToFloat(f32, fb.width) * (1 / @intToFloat(f32, width));
        const yh = @intToFloat(f32, fb.height) * (1 / @intToFloat(f32, height));
        for (xt, 0..) |*x, offset| x.* = @floatToInt(usize, xw * @intToFloat(f32, offset));

        for (0..height) |y| {
          const yoffset = fb.width * @floatToInt(usize, yh * @intToFloat(f32, y));

          const oso = os[yoffset..];
          const so = s[(y * width)..][0..width];
          for (so, xt) |*x, offset| x.* = oso[offset];
        }
      },

      else => {
        const convolution = opaque {
          const filters = struct {
            pub const box = struct {
              const support = 0.5;

              inline fn filter(x: f64) f64 {
                return if (x > -0.5 and x <= 0.5) 1 else 0;
              }
            };

            pub const bilinear = struct {
              const support = 1.0;

              inline fn filter(x: f64) f64 {
                const xx = if (x >= 0) x else -x;
                return if (1 <= xx) 0 else 1 - xx;
              }
            };

            pub const hamming = struct {
              const support = 1.0;

              inline fn filter(x: f64) f64 {
                const xx = if (x >= 0) x else -x;

                if (0 == xx) return 1;
                if (1 <= xx) return 0;
                const z = xx * std.math.pi;
                return @sin(z) / z * (0.54 + 0.46 * @cos(z));
              }
            };
          };

          fn coefficents(comptime krnl: std.meta.DeclEnum(filters)) !void {
            _ = @field(filters, @tagName(krnl));

            @panic("TODO");
          }

          fn resize(comptime krnl: std.meta.DeclEnum(filters)) !void {
            _ = try coefficents(krnl);

            @panic("TODO");
          }
        };

        try switch (kernel) {
          .nearest => unreachable,
          .box => convolution.resize(.box),
          .hamming => convolution.resize(.hamming),
          .bilinear => convolution.resize(.bilinear),
        };
      },
    }

    return nfb;
  }

  pub fn grayscale(fb: framebuffer, sigma: f32) void {
    var offset: usize = 0;
    const s = fb.slice(u32);
    @setFloatMode(.Optimized);
    const aligned = s.len & ~@as(usize, 0x07);
    const fsigma = std.math.clamp(sigma, 0.0, 1.0);
    const isigma = std.math.clamp(1.0 - fsigma, 0.0, 1.0);

    if (0 == fsigma) return;

    const f = [9]f32 {
      0.2126 + 0.7874 * isigma, 0.7152 - 0.7152 * isigma, 0.0722 - 0.0722 * isigma,
      0.2126 - 0.2126 * isigma, 0.7152 + 0.2848 * isigma, 0.0722 - 0.0722 * isigma,
      0.2126 - 0.2126 * isigma, 0.7152 - 0.7152 * isigma, 0.0722 + 0.9278 * isigma,
    };

    defer {
      for (s[aligned..]) |*c| {
        const rr = @intToFloat(f32, c.* & 0xff);
        const gg = @intToFloat(f32, (c.* >> 8) & 0xff);
        const bb = @intToFloat(f32, (c.* >> 16) & 0xff);
        const r = @min(255, @floatToInt(u32, rr * f[0] + gg * f[1] + bb * f[2]));
        const g = @min(255, @floatToInt(u32, rr * f[3] + gg * f[4] + bb * f[5]));
        const b = @min(255, @floatToInt(u32, rr * f[6] + gg * f[7] + bb * f[8]));

        c.* = r | (g << 8) | (b << 16) | (c.* >> 24 << 24);
      }
    }

    while (offset < aligned) : (offset += 8) {
      const c = s[offset..][0..8];
      const cv: @Vector(8, u32) = c.*;
      const max: @Vector(8, u32) = [_]u32 {255} ** 8;

      const rch = cv & @splat(8, @as(u32, 0xff));
      const gch = (cv >> @splat(8, @as(u5, 8))) & @splat(8, @as(u32, 0xff));
      const bch = (cv >> @splat(8, @as(u5, 16))) & @splat(8, @as(u32, 0xff));

      const rf = [8]f32 {
        @intToFloat(f32, rch[0]), @intToFloat(f32, rch[1]), @intToFloat(f32, rch[2]), @intToFloat(f32, rch[3]),
        @intToFloat(f32, rch[4]), @intToFloat(f32, rch[5]), @intToFloat(f32, rch[6]), @intToFloat(f32, rch[7]),
      };

      const gf = [8]f32 {
        @intToFloat(f32, gch[0]), @intToFloat(f32, gch[1]), @intToFloat(f32, gch[2]), @intToFloat(f32, gch[3]),
        @intToFloat(f32, gch[4]), @intToFloat(f32, gch[5]), @intToFloat(f32, gch[6]), @intToFloat(f32, gch[7]),
      };

      const bf = [8]f32 {
        @intToFloat(f32, bch[0]), @intToFloat(f32, bch[1]), @intToFloat(f32, bch[2]), @intToFloat(f32, bch[3]),
        @intToFloat(f32, bch[4]), @intToFloat(f32, bch[5]), @intToFloat(f32, bch[6]), @intToFloat(f32, bch[7]),
      };

      const rr = rf * @splat(8, f[0]) + gf * @splat(8, f[1]) + bf * @splat(8, f[2]);
      const gg = rf * @splat(8, f[3]) + gf * @splat(8, f[4]) + bf * @splat(8, f[5]);
      const bb = rf * @splat(8, f[6]) + gf * @splat(8, f[7]) + bf * @splat(8, f[8]);

      const r = @min(max, @Vector(8, u32) {
        @floatToInt(u32, rr[0]), @floatToInt(u32, rr[1]), @floatToInt(u32, rr[2]), @floatToInt(u32, rr[3]),
        @floatToInt(u32, rr[4]), @floatToInt(u32, rr[5]), @floatToInt(u32, rr[6]), @floatToInt(u32, rr[7]),
      });

      const g = @min(max, @Vector(8, u32) {
        @floatToInt(u32, gg[0]), @floatToInt(u32, gg[1]), @floatToInt(u32, gg[2]), @floatToInt(u32, gg[3]),
        @floatToInt(u32, gg[4]), @floatToInt(u32, gg[5]), @floatToInt(u32, gg[6]), @floatToInt(u32, gg[7]),
      });

      const b = @min(max, @Vector(8, u32) {
        @floatToInt(u32, bb[0]), @floatToInt(u32, bb[1]), @floatToInt(u32, bb[2]), @floatToInt(u32, bb[3]),
        @floatToInt(u32, bb[4]), @floatToInt(u32, bb[5]), @floatToInt(u32, bb[6]), @floatToInt(u32, bb[7]),
      });

      c.* = r | (g << @splat(8, @as(u5, 8))) | (b << @splat(8, @as(u5, 16))) | (cv >> @splat(8, @as(u5, 24)) << @splat(8, @as(u5, 24)));
    }
  }

  pub fn filter(fb: framebuffer, filtr: enum {
    sepia,
    opacity,
    saturate,
    contrast,
    hue_rotate,
    brightness,
  }, sigma: f32) void {
    var offset: usize = 0;
    const s = fb.slice(u32);
    @setFloatMode(.Optimized);
    const zsigma = @max(0, sigma);
    const aligned = s.len & ~@as(usize, 0x07);
    const fsigma = std.math.clamp(sigma, 0.0, 1.0);
    const isigma = std.math.clamp(1.0 - fsigma, 0.0, 1.0);

    switch (filtr) {
      .contrast => {
        if (1 == zsigma) return;
        const csigma = @floatToInt(i32, 255 * (0.5 - (0.5 * zsigma)));
        fb.linear(.{zsigma, zsigma, zsigma, 1}, .{csigma, csigma, csigma, 0});
      },

      .opacity => {
        if (1.0 == fsigma) return;

        if (0.0 == fsigma) {
          defer { for (s[aligned..]) |*c| c.* &= ~(@as(u32, 255) << 24); }
          while (offset < aligned) : (offset += 8) s[offset..][0..8].* &= ~(@splat(8, @as(u32, 255) << 24));
        }

        else {
          defer {
            for (s[aligned..]) |*c| {
              c.* = (c.* & @as(u32, 0xffffff)) | (@floatToInt(u32, fsigma * @intToFloat(f32, c.* >> 24)) << 24);
            }
          }

          while (offset < aligned) : (offset += 8) {
            const c = s[offset..][0..8];
            const a = @as(@Vector(8, u32), c.*) >> @splat(8, @as(u5, 24));

            const f = @splat(8, fsigma) * [8]f32 {
              @intToFloat(f32, a[0]), @intToFloat(f32, a[1]), @intToFloat(f32, a[2]), @intToFloat(f32, a[3]),
              @intToFloat(f32, a[4]), @intToFloat(f32, a[5]), @intToFloat(f32, a[6]), @intToFloat(f32, a[7]),
            };

            const ca: @Vector(8, u32) = .{
              @floatToInt(u32, f[0]), @floatToInt(u32, f[1]), @floatToInt(u32, f[2]), @floatToInt(u32, f[3]),
              @floatToInt(u32, f[4]), @floatToInt(u32, f[5]), @floatToInt(u32, f[6]), @floatToInt(u32, f[7]),
            };

            c.* = (c.* & @splat(8, @as(u32, 0xffffff))) | (ca << @splat(8, @as(u5, 24)));
          }
        }
      },

      .brightness => {
        if (1 == zsigma) return;

        defer {
          for (s[aligned..]) |*c| {
            const rr = @intToFloat(f32, c.* & 0xff);
            const gg = @intToFloat(f32, (c.* >> 8) & 0xff);
            const bb = @intToFloat(f32, (c.* >> 16) & 0xff);
            const r = @min(255, @floatToInt(u32, rr * zsigma));
            const g = @min(255, @floatToInt(u32, gg * zsigma));
            const b = @min(255, @floatToInt(u32, bb * zsigma));

            c.* = r | (g << 8) | (b << 16) | (c.* >> 24 << 24);
          }
        }

        while (offset < aligned) : (offset += 8) {
          const c = s[offset..][0..8];
          const cv: @Vector(8, u32) = c.*;
          const max: @Vector(8, u32) = [_]u32 {255} ** 8;

          const rch = cv & @splat(8, @as(u32, 0xff));
          const gch = (cv >> @splat(8, @as(u5, 8))) & @splat(8, @as(u32, 0xff));
          const bch = (cv >> @splat(8, @as(u5, 16))) & @splat(8, @as(u32, 0xff));

          const rf = @splat(8, zsigma) * [8]f32 {
            @intToFloat(f32, rch[0]), @intToFloat(f32, rch[1]), @intToFloat(f32, rch[2]), @intToFloat(f32, rch[3]),
            @intToFloat(f32, rch[4]), @intToFloat(f32, rch[5]), @intToFloat(f32, rch[6]), @intToFloat(f32, rch[7]),
          };

          const gf = @splat(8, zsigma) * [8]f32 {
            @intToFloat(f32, gch[0]), @intToFloat(f32, gch[1]), @intToFloat(f32, gch[2]), @intToFloat(f32, gch[3]),
            @intToFloat(f32, gch[4]), @intToFloat(f32, gch[5]), @intToFloat(f32, gch[6]), @intToFloat(f32, gch[7]),
          };

          const bf = @splat(8, zsigma) * [8]f32 {
            @intToFloat(f32, bch[0]), @intToFloat(f32, bch[1]), @intToFloat(f32, bch[2]), @intToFloat(f32, bch[3]),
            @intToFloat(f32, bch[4]), @intToFloat(f32, bch[5]), @intToFloat(f32, bch[6]), @intToFloat(f32, bch[7]),
          };

          const r = @min(max, @Vector(8, u32) {
            @floatToInt(u32, rf[0]), @floatToInt(u32, rf[1]), @floatToInt(u32, rf[2]), @floatToInt(u32, rf[3]),
            @floatToInt(u32, rf[4]), @floatToInt(u32, rf[5]), @floatToInt(u32, rf[6]), @floatToInt(u32, rf[7]),
          });

          const g = @min(max, @Vector(8, u32) {
            @floatToInt(u32, gf[0]), @floatToInt(u32, gf[1]), @floatToInt(u32, gf[2]), @floatToInt(u32, gf[3]),
            @floatToInt(u32, gf[4]), @floatToInt(u32, gf[5]), @floatToInt(u32, gf[6]), @floatToInt(u32, gf[7]),
          });

          const b = @min(max, @Vector(8, u32) {
            @floatToInt(u32, bf[0]), @floatToInt(u32, bf[1]), @floatToInt(u32, bf[2]), @floatToInt(u32, bf[3]),
            @floatToInt(u32, bf[4]), @floatToInt(u32, bf[5]), @floatToInt(u32, bf[6]), @floatToInt(u32, bf[7]),
          });

          c.* = r | (g << @splat(8, @as(u5, 8))) | (b << @splat(8, @as(u5, 16))) | (cv >> @splat(8, @as(u5, 24)) << @splat(8, @as(u5, 24)));
        }
      },

      .sepia => {
        if (0 == fsigma) return;

        const f = [9]f32 {
          0.393 + 0.607 * isigma, 0.769 - 0.769 * isigma, 0.189 - 0.189 * isigma,
          0.349 - 0.349 * isigma, 0.686 + 0.314 * isigma, 0.168 - 0.168 * isigma,
          0.272 - 0.272 * isigma, 0.534 - 0.534 * isigma, 0.131 + 0.869 * isigma,
        };

        defer {
          for (s[aligned..]) |*c| {
            const rr = @intToFloat(f32, c.* & 0xff);
            const gg = @intToFloat(f32, (c.* >> 8) & 0xff);
            const bb = @intToFloat(f32, (c.* >> 16) & 0xff);
            const r = @min(255, @floatToInt(u32, rr * f[0] + gg * f[1] + bb * f[2]));
            const g = @min(255, @floatToInt(u32, rr * f[3] + gg * f[4] + bb * f[5]));
            const b = @min(255, @floatToInt(u32, rr * f[6] + gg * f[7] + bb * f[8]));

            c.* = r | (g << 8) | (b << 16) | (c.* >> 24 << 24);
          }
        }

        while (offset < aligned) : (offset += 8) {
          const c = s[offset..][0..8];
          const cv: @Vector(8, u32) = c.*;
          const max: @Vector(8, u32) = [_]u32 {255} ** 8;

          const rch = cv & @splat(8, @as(u32, 0xff));
          const gch = (cv >> @splat(8, @as(u5, 8))) & @splat(8, @as(u32, 0xff));
          const bch = (cv >> @splat(8, @as(u5, 16))) & @splat(8, @as(u32, 0xff));

          const rf = [8]f32 {
            @intToFloat(f32, rch[0]), @intToFloat(f32, rch[1]), @intToFloat(f32, rch[2]), @intToFloat(f32, rch[3]),
            @intToFloat(f32, rch[4]), @intToFloat(f32, rch[5]), @intToFloat(f32, rch[6]), @intToFloat(f32, rch[7]),
          };

          const gf = [8]f32 {
            @intToFloat(f32, gch[0]), @intToFloat(f32, gch[1]), @intToFloat(f32, gch[2]), @intToFloat(f32, gch[3]),
            @intToFloat(f32, gch[4]), @intToFloat(f32, gch[5]), @intToFloat(f32, gch[6]), @intToFloat(f32, gch[7]),
          };

          const bf = [8]f32 {
            @intToFloat(f32, bch[0]), @intToFloat(f32, bch[1]), @intToFloat(f32, bch[2]), @intToFloat(f32, bch[3]),
            @intToFloat(f32, bch[4]), @intToFloat(f32, bch[5]), @intToFloat(f32, bch[6]), @intToFloat(f32, bch[7]),
          };

          const rr = rf * @splat(8, f[0]) + gf * @splat(8, f[1]) + bf * @splat(8, f[2]);
          const gg = rf * @splat(8, f[3]) + gf * @splat(8, f[4]) + bf * @splat(8, f[5]);
          const bb = rf * @splat(8, f[6]) + gf * @splat(8, f[7]) + bf * @splat(8, f[8]);

          const r = @min(max, @Vector(8, u32) {
            @floatToInt(u32, rr[0]), @floatToInt(u32, rr[1]), @floatToInt(u32, rr[2]), @floatToInt(u32, rr[3]),
            @floatToInt(u32, rr[4]), @floatToInt(u32, rr[5]), @floatToInt(u32, rr[6]), @floatToInt(u32, rr[7]),
          });

          const g = @min(max, @Vector(8, u32) {
            @floatToInt(u32, gg[0]), @floatToInt(u32, gg[1]), @floatToInt(u32, gg[2]), @floatToInt(u32, gg[3]),
            @floatToInt(u32, gg[4]), @floatToInt(u32, gg[5]), @floatToInt(u32, gg[6]), @floatToInt(u32, gg[7]),
          });

          const b = @min(max, @Vector(8, u32) {
            @floatToInt(u32, bb[0]), @floatToInt(u32, bb[1]), @floatToInt(u32, bb[2]), @floatToInt(u32, bb[3]),
            @floatToInt(u32, bb[4]), @floatToInt(u32, bb[5]), @floatToInt(u32, bb[6]), @floatToInt(u32, bb[7]),
          });

          c.* = r | (g << @splat(8, @as(u5, 8))) | (b << @splat(8, @as(u5, 16))) | (cv >> @splat(8, @as(u5, 24)) << @splat(8, @as(u5, 24)));
        }
      },

      .saturate => {
        if (1 == zsigma) return;

        const f = [9]f32 {
          0.213 + 0.787 * zsigma, 0.715 - 0.715 * zsigma, 0.072 - 0.072 * zsigma,
          0.213 - 0.213 * zsigma, 0.715 + 0.285 * zsigma, 0.072 - 0.072 * zsigma,
          0.213 - 0.213 * zsigma, 0.715 - 0.715 * zsigma, 0.072 + 0.928 * zsigma,
        };

        defer {
          for (s[aligned..]) |*c| {
            const rr = @intToFloat(f32, c.* & 0xff);
            const gg = @intToFloat(f32, (c.* >> 8) & 0xff);
            const bb = @intToFloat(f32, (c.* >> 16) & 0xff);
            const r = @min(255, @floatToInt(u32, rr * f[0] + gg * f[1] + bb * f[2]));
            const g = @min(255, @floatToInt(u32, rr * f[3] + gg * f[4] + bb * f[5]));
            const b = @min(255, @floatToInt(u32, rr * f[6] + gg * f[7] + bb * f[8]));

            c.* = r | (g << 8) | (b << 16) | (c.* >> 24 << 24);
          }
        }

        while (offset < aligned) : (offset += 8) {
          const c = s[offset..][0..8];
          const cv: @Vector(8, u32) = c.*;
          const max: @Vector(8, u32) = [_]u32 {255} ** 8;

          const rch = cv & @splat(8, @as(u32, 0xff));
          const gch = (cv >> @splat(8, @as(u5, 8))) & @splat(8, @as(u32, 0xff));
          const bch = (cv >> @splat(8, @as(u5, 16))) & @splat(8, @as(u32, 0xff));

          const rf = [8]f32 {
            @intToFloat(f32, rch[0]), @intToFloat(f32, rch[1]), @intToFloat(f32, rch[2]), @intToFloat(f32, rch[3]),
            @intToFloat(f32, rch[4]), @intToFloat(f32, rch[5]), @intToFloat(f32, rch[6]), @intToFloat(f32, rch[7]),
          };

          const gf = [8]f32 {
            @intToFloat(f32, gch[0]), @intToFloat(f32, gch[1]), @intToFloat(f32, gch[2]), @intToFloat(f32, gch[3]),
            @intToFloat(f32, gch[4]), @intToFloat(f32, gch[5]), @intToFloat(f32, gch[6]), @intToFloat(f32, gch[7]),
          };

          const bf = [8]f32 {
            @intToFloat(f32, bch[0]), @intToFloat(f32, bch[1]), @intToFloat(f32, bch[2]), @intToFloat(f32, bch[3]),
            @intToFloat(f32, bch[4]), @intToFloat(f32, bch[5]), @intToFloat(f32, bch[6]), @intToFloat(f32, bch[7]),
          };

          const rr = rf * @splat(8, f[0]) + gf * @splat(8, f[1]) + bf * @splat(8, f[2]);
          const gg = rf * @splat(8, f[3]) + gf * @splat(8, f[4]) + bf * @splat(8, f[5]);
          const bb = rf * @splat(8, f[6]) + gf * @splat(8, f[7]) + bf * @splat(8, f[8]);

          const r = @min(max, @Vector(8, u32) {
            @floatToInt(u32, rr[0]), @floatToInt(u32, rr[1]), @floatToInt(u32, rr[2]), @floatToInt(u32, rr[3]),
            @floatToInt(u32, rr[4]), @floatToInt(u32, rr[5]), @floatToInt(u32, rr[6]), @floatToInt(u32, rr[7]),
          });

          const g = @min(max, @Vector(8, u32) {
            @floatToInt(u32, gg[0]), @floatToInt(u32, gg[1]), @floatToInt(u32, gg[2]), @floatToInt(u32, gg[3]),
            @floatToInt(u32, gg[4]), @floatToInt(u32, gg[5]), @floatToInt(u32, gg[6]), @floatToInt(u32, gg[7]),
          });

          const b = @min(max, @Vector(8, u32) {
            @floatToInt(u32, bb[0]), @floatToInt(u32, bb[1]), @floatToInt(u32, bb[2]), @floatToInt(u32, bb[3]),
            @floatToInt(u32, bb[4]), @floatToInt(u32, bb[5]), @floatToInt(u32, bb[6]), @floatToInt(u32, bb[7]),
          });

          c.* = r | (g << @splat(8, @as(u5, 8))) | (b << @splat(8, @as(u5, 16))) | (cv >> @splat(8, @as(u5, 24)) << @splat(8, @as(u5, 24)));
        }
      },

      .hue_rotate => {
        if (0 == @mod(sigma, 360)) return;
        const cos = @cos(sigma * (std.math.pi / 180.0));
        const sin = @sin(sigma * (std.math.pi / 180.0));

        const f = [9]f32 {
          0.213 + cos * 0.787 - sin * 0.213, 0.715 - cos * 0.715 - sin * 0.715, 0.072 - cos * 0.072 + sin * 0.928,
          0.213 - cos * 0.213 + sin * 0.143, 0.715 + cos * 0.285 + sin * 0.140, 0.072 - cos * 0.072 - sin * 0.283,
          0.213 - cos * 0.213 - sin * 0.787, 0.715 - cos * 0.715 + sin * 0.715, 0.072 + cos * 0.928 + sin * 0.072,
        };

        defer {
          for (s[aligned..]) |*c| {
            const rr = @intToFloat(f32, c.* & 0xff);
            const gg = @intToFloat(f32, (c.* >> 8) & 0xff);
            const bb = @intToFloat(f32, (c.* >> 16) & 0xff);
            const r = @min(255, @floatToInt(u32, rr * f[0] + gg * f[1] + bb * f[2]));
            const g = @min(255, @floatToInt(u32, rr * f[3] + gg * f[4] + bb * f[5]));
            const b = @min(255, @floatToInt(u32, rr * f[6] + gg * f[7] + bb * f[8]));

            c.* = r | (g << 8) | (b << 16) | (c.* >> 24 << 24);
          }
        }

        while (offset < aligned) : (offset += 8) {
          const c = s[offset..][0..8];
          const cv: @Vector(8, u32) = c.*;
          const max: @Vector(8, u32) = [_]u32 {255} ** 8;

          const rch = cv & @splat(8, @as(u32, 0xff));
          const gch = (cv >> @splat(8, @as(u5, 8))) & @splat(8, @as(u32, 0xff));
          const bch = (cv >> @splat(8, @as(u5, 16))) & @splat(8, @as(u32, 0xff));

          const rf = [8]f32 {
            @intToFloat(f32, rch[0]), @intToFloat(f32, rch[1]), @intToFloat(f32, rch[2]), @intToFloat(f32, rch[3]),
            @intToFloat(f32, rch[4]), @intToFloat(f32, rch[5]), @intToFloat(f32, rch[6]), @intToFloat(f32, rch[7]),
          };

          const gf = [8]f32 {
            @intToFloat(f32, gch[0]), @intToFloat(f32, gch[1]), @intToFloat(f32, gch[2]), @intToFloat(f32, gch[3]),
            @intToFloat(f32, gch[4]), @intToFloat(f32, gch[5]), @intToFloat(f32, gch[6]), @intToFloat(f32, gch[7]),
          };

          const bf = [8]f32 {
            @intToFloat(f32, bch[0]), @intToFloat(f32, bch[1]), @intToFloat(f32, bch[2]), @intToFloat(f32, bch[3]),
            @intToFloat(f32, bch[4]), @intToFloat(f32, bch[5]), @intToFloat(f32, bch[6]), @intToFloat(f32, bch[7]),
          };

          const rr = rf * @splat(8, f[0]) + gf * @splat(8, f[1]) + bf * @splat(8, f[2]);
          const gg = rf * @splat(8, f[3]) + gf * @splat(8, f[4]) + bf * @splat(8, f[5]);
          const bb = rf * @splat(8, f[6]) + gf * @splat(8, f[7]) + bf * @splat(8, f[8]);

          const r = @min(max, @Vector(8, u32) {
            @floatToInt(u32, rr[0]), @floatToInt(u32, rr[1]), @floatToInt(u32, rr[2]), @floatToInt(u32, rr[3]),
            @floatToInt(u32, rr[4]), @floatToInt(u32, rr[5]), @floatToInt(u32, rr[6]), @floatToInt(u32, rr[7]),
          });

          const g = @min(max, @Vector(8, u32) {
            @floatToInt(u32, gg[0]), @floatToInt(u32, gg[1]), @floatToInt(u32, gg[2]), @floatToInt(u32, gg[3]),
            @floatToInt(u32, gg[4]), @floatToInt(u32, gg[5]), @floatToInt(u32, gg[6]), @floatToInt(u32, gg[7]),
          });

          const b = @min(max, @Vector(8, u32) {
            @floatToInt(u32, bb[0]), @floatToInt(u32, bb[1]), @floatToInt(u32, bb[2]), @floatToInt(u32, bb[3]),
            @floatToInt(u32, bb[4]), @floatToInt(u32, bb[5]), @floatToInt(u32, bb[6]), @floatToInt(u32, bb[7]),
          });

          c.* = r | (g << @splat(8, @as(u5, 8))) | (b << @splat(8, @as(u5, 16))) | (cv >> @splat(8, @as(u5, 24)) << @splat(8, @as(u5, 24)));
        }
      },
    }
  }
};