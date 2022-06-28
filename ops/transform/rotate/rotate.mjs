import { to_u32 } from '../../_.mjs';
import framebuffer from '../../../framebuffer.mjs';
import matrix, { rotate as mrotate } from '../matrix/matrix.mjs';

export default rotate;

export function rotate180(fb) {
  const u32 = to_u32(fb.buffer).slice();
  return framebuffer(fb.width, fb.height, u32.reverse());
}

export function rotate(fb, deg, resize = true) {
  deg = deg % 360.0;

  if (180.0 === deg) return rotate180(fb);
  if (resize && 90.0 === deg) return rotate90(fb);
  if (resize && 270.0 === deg) return rotate270(fb);

  return matrix(fb, ...mrotate(deg), resize);
}

export function rotate90(fb) {
  const width = fb.width;
  const height = fb.height;
  const nfb = framebuffer(height, width);

  const o32 = to_u32(fb.buffer);
  const u32 = to_u32(nfb.buffer);

  for (let y = 0; y < height; y += 1) {
    const yoffset = y * width;
    const heighty1 = height - 1 - y;

    for (let x = 0; x < width; x += 1) {
      u32[heighty1 + x * height] = o32[x + yoffset];
    }
  }

  return nfb;
}

export function rotate270(fb) {
  const width = fb.width;
  const height = fb.height;
  const nfb = framebuffer(height, width);

  const width1 = width - 1;
  const o32 = to_u32(fb.buffer);
  const u32 = to_u32(nfb.buffer);

  for (let y = 0; y < height; y += 1) {
    const yoffset = y * width;

    for (let x = 0; x < width; x += 1) {
      u32[y + height * (width1 - x)] = o32[x + yoffset];
    }
  }

  return nfb;
}