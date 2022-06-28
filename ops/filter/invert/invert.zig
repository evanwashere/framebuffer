pub fn invert(fb: framebuffer, amount: f32) void {
  @setFloatMode(.Optimized);
  const famount = std.math.clamp(amount, 0.0, 1.0);
  const iamount = std.math.clamp(1.0 - amount, 0.0, 1.0);

  if (1.0 == famount) {
    for (fb.slice(u32)) |*cc| {
      const c = cc.*;

      switch (endianness) {
        .Big => cc.* = ~(c >> 8) << 8 | (c & 0xff),
        .Little => cc.* = ~c & 0xffffff | (c >> 24 << 24),
      }
    }
  }

  else for (fb.slice(u32)) |*cc| {
    const c = cc.*;
    const rr = @intToFloat(f32, switch (endianness) { .Big => (c >> 24),        .Little => (c) & 0xff });
    const gg = @intToFloat(f32, switch (endianness) { .Big => (c >> 16) & 0xff, .Little => (c >> 8) & 0xff });
    const bb = @intToFloat(f32, switch (endianness) { .Big => (c >>  8) & 0xff, .Little => (c >> 16) & 0xff });

    const r = @floatToInt(u32, rr * iamount + famount * (255.0 - rr));
    const g = @floatToInt(u32, gg * iamount + famount * (255.0 - gg));
    const b = @floatToInt(u32, bb * iamount + famount * (255.0 - bb));

    switch (endianness) {
      .Big => cc.* = (c & 0xff) | (b << 8) | (g << 16) | (r << 24),
      .Little => cc.* = r | (g << 8) | (b << 16) | (c >> 24 << 24),
    }
  }
}