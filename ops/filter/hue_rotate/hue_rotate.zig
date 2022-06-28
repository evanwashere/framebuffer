pub fn hue_rotate(fb: framebuffer, deg: f32) void {
  @setFloatMode(.Optimized);
  const cos = @cos(deg * (std.math.pi / 180.0));
  const sin = @sin(deg * (std.math.pi / 180.0));

  const filter = [9]f32 {
    0.213 + cos * 0.787 - sin * 0.213, 0.715 - cos * 0.715 - sin * 0.715, 0.072 - cos * 0.072 + sin * 0.928,
    0.213 - cos * 0.213 + sin * 0.143, 0.715 + cos * 0.285 + sin * 0.140, 0.072 - cos * 0.072 - sin * 0.283,
    0.213 - cos * 0.213 - sin * 0.787, 0.715 - cos * 0.715 + sin * 0.715, 0.072 + cos * 0.928 + sin * 0.072,
  };

  for (fb.slice(u32)) |*cc| {
    const c = cc.*;
    const rr = @intToFloat(f32, switch (endianness) { .Big => (c >> 24),        .Little => (c) & 0xff });
    const gg = @intToFloat(f32, switch (endianness) { .Big => (c >> 16) & 0xff, .Little => (c >> 8) & 0xff });
    const bb = @intToFloat(f32, switch (endianness) { .Big => (c >>  8) & 0xff, .Little => (c >> 16) & 0xff });

    const r = std.math.clamp(@floatToInt(u32, rr * filter[0] + gg * filter[1] + bb * filter[2]), 0, 255);
    const g = std.math.clamp(@floatToInt(u32, rr * filter[3] + gg * filter[4] + bb * filter[5]), 0, 255);
    const b = std.math.clamp(@floatToInt(u32, rr * filter[6] + gg * filter[7] + bb * filter[8]), 0, 255);

    switch (endianness) {
      .Big => cc.* = (c & 0xff) | (b << 8) | (g << 16) | (r << 24),
      .Little => cc.* = r | (g << 8) | (b << 16) | (c >> 24 << 24),
    }
  }
}