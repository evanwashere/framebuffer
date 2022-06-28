pub fn sepia(fb: framebuffer, amount: f32) void {
  @setFloatMode(.Optimized);
  const iamount = std.math.clamp(1.0 - amount, 0.0, 1.0);

  const filter = [9]f32 {
    0.393 + 0.607 * iamount, 0.769 - 0.769 * iamount, 0.189 - 0.189 * iamount,
    0.349 - 0.349 * iamount, 0.686 + 0.314 * iamount, 0.168 - 0.168 * iamount,
    0.272 - 0.272 * iamount, 0.534 - 0.534 * iamount, 0.131 + 0.869 * iamount,
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