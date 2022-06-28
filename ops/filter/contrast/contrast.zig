pub fn contrast(fb: framebuffer, amount: f32) void {
  @setFloatMode(.Optimized);
  const iamount = 255 * (0.5 - (0.5 * amount));

  for (fb.slice(u32)) |*cc| {
    const c = cc.*;
    const rr = @intToFloat(f32, switch (endianness) { .Big => (c >> 24),        .Little => (c) & 0xff });
    const gg = @intToFloat(f32, switch (endianness) { .Big => (c >> 16) & 0xff, .Little => (c >> 8) & 0xff });
    const bb = @intToFloat(f32, switch (endianness) { .Big => (c >>  8) & 0xff, .Little => (c >> 16) & 0xff });

    const r = std.math.clamp(@floatToInt(u32, iamount + rr * amount), 0, 255);
    const g = std.math.clamp(@floatToInt(u32, iamount + gg * amount), 0, 255);
    const b = std.math.clamp(@floatToInt(u32, iamount + bb * amount), 0, 255);

    switch (endianness) {
      .Big => cc.* = (c & 0xff) | (b << 8) | (g << 16) | (r << 24),
      .Little => cc.* = r | (g << 8) | (b << 16) | (c >> 24 << 24),
    }
  }
}