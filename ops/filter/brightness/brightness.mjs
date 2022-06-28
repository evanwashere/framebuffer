import { wasm, simd, clamp, to_u32, endianness } from '../../_.mjs';

let mod = null;
const st = 128 * 1024;
const ceil = Math.ceil;

export default function brightness(fb, amount) {
  const len = fb.buffer.length;
  if (wasm && simd && st < len) return brightness_simd(fb, amount);
  else return (endianness ? brightness_le : brightness_be)(fb, amount);
}

export function brightness_simd(fb, amount) {
  if (mod === null) init_mod();
  const { memory, brightness } = new WebAssembly.Instance(mod).exports;

  memory.grow(ceil((16 + fb.buffer.length) / 65536));

  const u32 = to_u32(fb.buffer);
  const o32 = new Uint32Array(memory.buffer, 16, u32.length);
  o32.set(u32); brightness(fb.width, fb.height, amount); u32.set(o32);
}

export function brightness_le(fb, amount) {
  const u32 = to_u32(fb.buffer);
  const len = fb.buffer.length / 4;

  for (let offset = 0; len > offset; offset += 1) {
    const c = u32[offset];

    const rr = c & 0xff;
    const gg = (c >> 8) & 0xff;
    const bb = (c >> 16) & 0xff;

    const r = clamp(0, (rr * amount) | 0, 255);
    const g = clamp(0, (gg * amount) | 0, 255);
    const b = clamp(0, (bb * amount) | 0, 255);

    u32[offset] = r | (g << 8) | (b << 16) | (c >> 24 << 24);
  }
}

export function brightness_be(fb, amount) {
  const u32 = to_u32(fb.buffer);
  const len = fb.buffer.length / 4;

  for (let offset = 0; len > offset; offset += 1) {
    const c = u32[offset];

    const rr = (c >> 24) & 0xff;
    const gg = (c >> 16) & 0xff;
    const bb = (c >>  8) & 0xff;

    const r = clamp(0, (rr * amount) | 0, 255);
    const g = clamp(0, (gg * amount) | 0, 255);
    const b = clamp(0, (bb * amount) | 0, 255);

    u32[offset] = (c & 0xff) | (b << 8) | (g << 16) | (r << 24);
  }
}

function init_mod() {
  mod = new WebAssembly.Module(Uint8Array.of(0,97,115,109,1,0,0,0,1,7,1,96,3,127,127,125,0,3,2,1,0,5,3,1,0,1,7,23,2,6,109,101,109,111,114,121,2,0,10,98,114,105,103,104,116,110,101,115,115,0,0,10,210,3,1,207,3,2,2,127,2,123,2,64,32,0,32,1,108,34,0,65,2,116,69,13,0,32,0,65,255,255,255,255,3,113,34,0,65,1,32,0,65,1,75,27,34,4,65,4,79,4,64,32,2,253,19,33,5,65,16,33,0,32,4,65,252,255,255,255,3,113,34,3,33,1,3,64,32,0,32,5,32,0,253,0,4,0,34,6,65,8,253,173,1,253,12,255,0,0,0,255,0,0,0,255,0,0,0,255,0,0,0,253,78,253,251,1,253,230,1,253,249,1,253,12,255,0,0,0,255,0,0,0,255,0,0,0,255,0,0,0,253,183,1,65,8,253,171,1,32,5,32,6,253,12,255,0,0,0,255,0,0,0,255,0,0,0,255,0,0,0,253,78,253,251,1,253,230,1,253,249,1,253,12,255,0,0,0,255,0,0,0,255,0,0,0,255,0,0,0,253,183,1,253,80,32,5,32,6,65,16,253,173,1,253,12,255,0,0,0,255,0,0,0,255,0,0,0,255,0,0,0,253,78,253,251,1,253,230,1,253,249,1,253,12,255,0,0,0,255,0,0,0,255,0,0,0,255,0,0,0,253,183,1,65,16,253,171,1,253,80,32,6,253,12,0,0,0,255,0,0,0,255,0,0,0,255,0,0,0,255,253,78,253,80,253,11,4,0,32,0,65,16,106,33,0,32,1,65,4,107,34,1,13,0,11,32,3,32,4,70,13,1,11,32,4,32,3,107,33,4,32,3,65,2,116,65,16,106,33,0,3,64,32,0,40,2,0,34,1,65,8,118,65,255,1,113,179,32,2,148,252,1,33,3,32,0,32,1,65,128,128,128,120,113,32,3,65,255,1,32,3,65,255,1,73,27,65,8,116,32,1,65,255,1,113,179,32,2,148,252,1,34,3,65,255,1,32,3,65,255,1,73,27,114,32,1,65,16,118,65,255,1,113,179,32,2,148,252,1,34,1,65,255,1,32,1,65,255,1,73,27,65,16,116,114,114,54,2,0,32,0,65,4,106,33,0,32,4,65,1,107,34,4,13,0,11,11,11));
}