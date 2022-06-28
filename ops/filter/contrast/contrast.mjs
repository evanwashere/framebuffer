import { wasm, simd, clamp, to_u32, endianness } from '../../_.mjs';

let mod = null;
const st = 64 * 1024;
const ceil = Math.ceil;

export default function contrast(fb, amount) {
  const len = fb.buffer.length;
  if (wasm && simd && st < len) return contrast_simd(fb, amount);
  else return (endianness ? contrast_le : contrast_be)(fb, amount);
}

export function contrast_simd(fb, amount) {
  if (mod === null) init_mod();
  const { memory, contrast } = new WebAssembly.Instance(mod).exports;

  memory.grow(ceil((16 + fb.buffer.length) / 65536));

  const u32 = to_u32(fb.buffer);
  const o32 = new Uint32Array(memory.buffer, 16, u32.length);
  o32.set(u32); contrast(fb.width, fb.height, amount); u32.set(o32);
}

export function contrast_le(fb, amount) {
  const u32 = to_u32(fb.buffer);
  const len = fb.buffer.length / 4;
  const iamount = 255 * (0.5 - (0.5 * amount));

  for (let offset = 0; len > offset; offset += 1) {
    const c = u32[offset];

    const rr = c & 0xff;
    const gg = (c >> 8) & 0xff;
    const bb = (c >> 16) & 0xff;

    const r = clamp(0, (iamount + rr * amount) | 0, 255);
    const g = clamp(0, (iamount + gg * amount) | 0, 255);
    const b = clamp(0, (iamount + bb * amount) | 0, 255);

    u32[offset] = r | (g << 8) | (b << 16) | (c >> 24 << 24);
  }
}

export function contrast_be(fb, amount) {
  const u32 = to_u32(fb.buffer);
  const len = fb.buffer.length / 4;
  const iamount = 255 * (0.5 - (0.5 * amount));

  for (let offset = 0; len > offset; offset += 1) {
    const c = u32[offset];

    const rr = (c >> 24) & 0xff;
    const gg = (c >> 16) & 0xff;
    const bb = (c >>  8) & 0xff;

    const r = clamp(0, (iamount + rr * amount) | 0, 255);
    const g = clamp(0, (iamount + gg * amount) | 0, 255);
    const b = clamp(0, (iamount + bb * amount) | 0, 255);

    u32[offset] = (c & 0xff) | (b << 8) | (g << 16) | (r << 24);
  }
}

function init_mod() {
  mod = new WebAssembly.Module(Uint8Array.of(0,97,115,109,1,0,0,0,1,7,1,96,3,127,127,125,0,3,2,1,0,5,3,1,0,1,7,21,2,6,109,101,109,111,114,121,2,0,8,99,111,110,116,114,97,115,116,0,0,10,130,4,1,255,3,3,2,127,1,125,3,123,2,64,32,0,32,1,108,34,0,65,2,116,69,13,0,67,0,0,255,66,32,2,67,0,0,255,66,148,147,33,5,32,0,65,255,255,255,255,3,113,34,0,65,1,32,0,65,1,75,27,34,4,65,4,79,4,64,32,5,253,19,33,6,32,2,253,19,33,7,65,16,33,0,32,4,65,252,255,255,255,3,113,34,3,33,1,3,64,32,0,32,7,32,0,253,0,4,0,34,8,65,8,253,173,1,253,12,255,0,0,0,255,0,0,0,255,0,0,0,255,0,0,0,253,78,253,251,1,253,230,1,32,6,253,228,1,253,249,1,253,12,255,0,0,0,255,0,0,0,255,0,0,0,255,0,0,0,253,183,1,65,8,253,171,1,32,7,32,8,253,12,255,0,0,0,255,0,0,0,255,0,0,0,255,0,0,0,253,78,253,251,1,253,230,1,32,6,253,228,1,253,249,1,253,12,255,0,0,0,255,0,0,0,255,0,0,0,255,0,0,0,253,183,1,253,80,32,7,32,8,65,16,253,173,1,253,12,255,0,0,0,255,0,0,0,255,0,0,0,255,0,0,0,253,78,253,251,1,253,230,1,32,6,253,228,1,253,249,1,253,12,255,0,0,0,255,0,0,0,255,0,0,0,255,0,0,0,253,183,1,65,16,253,171,1,253,80,32,8,253,12,0,0,0,255,0,0,0,255,0,0,0,255,0,0,0,255,253,78,253,80,253,11,4,0,32,0,65,16,106,33,0,32,1,65,4,107,34,1,13,0,11,32,3,32,4,70,13,1,11,32,4,32,3,107,33,4,32,3,65,2,116,65,16,106,33,0,3,64,32,0,40,2,0,34,1,65,8,118,65,255,1,113,179,32,2,148,32,5,146,252,1,33,3,32,0,32,1,65,128,128,128,120,113,32,3,65,255,1,32,3,65,255,1,73,27,65,8,116,32,1,65,255,1,113,179,32,2,148,32,5,146,252,1,34,3,65,255,1,32,3,65,255,1,73,27,114,32,1,65,16,118,65,255,1,113,179,32,2,148,32,5,146,252,1,34,1,65,255,1,32,1,65,255,1,73,27,65,16,116,114,114,54,2,0,32,0,65,4,106,33,0,32,4,65,1,107,34,4,13,0,11,11,11));
}