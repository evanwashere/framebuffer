import { to_u32 } from '../../_.mjs';
import framebuffer from '../../../framebuffer.mjs';

export default nearest;

export function nearest(fb, width, height) {
  const w = fb.width;
  const h = fb.height;
  const o32 = to_u32(fb.buffer);
  const u32 = new Uint32Array(width * height);

  const xw = w * (1.0 / width);
  const yw = h * (1.0 / height);

  for (let y = 0; y < height; y++) {
    const yoffset = y * width;
    const yyoffset = w * ((y * yw) | 0);

    for (let x = 0; x < width; x++) {
      u32[x + yoffset] = o32[yyoffset + ((x * xw) | 0)];
    }
  }

  return framebuffer(width, height, u32);
}