pub fn opacity(fb: framebuffer, amount: f32) void {
  const iamount = std.math.clamp(amount, 0.0, 1.0);

  for (fb.slice(u32)) |*cc| {
    const c = cc.*;
    const aa = @intToFloat(f32, switch (endianness) { .Big => (c) & 0xff, .Little => (c >> 24) });

    const a = @floatToInt(u32, aa * iamount);

    switch (endianness) {
      .Big => cc.* = (a) | (c >> 8 << 8),
      .Little => cc.* = (c & 0xffffff) | (a << 24),
    }
  }
}