pub fn brightness(fb: framebuffer, amount: f32) void {
  @setFloatMode(.Optimized);

  for (fb.slice(u32)) |*cc| {
    const c = cc.*;
    const rr = @intToFloat(f32, switch (endianness) { .Big => (c >> 24),        .Little => (c) & 0xff });
    const gg = @intToFloat(f32, switch (endianness) { .Big => (c >> 16) & 0xff, .Little => (c >> 8) & 0xff });
    const bb = @intToFloat(f32, switch (endianness) { .Big => (c >>  8) & 0xff, .Little => (c >> 16) & 0xff });

    const r = std.math.clamp(@floatToInt(u32, rr * amount), 0, 255);
    const g = std.math.clamp(@floatToInt(u32, gg * amount), 0, 255);
    const b = std.math.clamp(@floatToInt(u32, bb * amount), 0, 255);

    switch (endianness) {
      .Big => cc.* = (c & 0xff) | (b << 8) | (g << 16) | (r << 24),
      .Little => cc.* = r | (g << 8) | (b << 16) | (c >> 24 << 24),
    }
  }
}