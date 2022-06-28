import { wasm, simd, clamp, to_u32, endianness } from '../../_.mjs';

let mod = null;
const st = 64 * 1024;
const ceil = Math.ceil;

export default function grayscale(fb, amount) {
  const len = fb.buffer.length;
  if (wasm && simd && st < len) return grayscale_simd(fb, amount);
  else return (endianness ? grayscale_le : grayscale_be)(fb, amount);
}

export function grayscale_simd(fb, amount) {
  if (mod === null) init_mod();
  const { memory, grayscale } = new WebAssembly.Instance(mod).exports;

  memory.grow(ceil((16 + fb.buffer.length) / 65536));

  const u32 = to_u32(fb.buffer);
  const o32 = new Uint32Array(memory.buffer, 16, u32.length);
  o32.set(u32); grayscale(fb.width, fb.height, amount); u32.set(o32);
}

export function grayscale_le(fb, amount) {
  const u32 = to_u32(fb.buffer);
  const len = fb.buffer.length / 4;
  amount = clamp(0.0, 1.0 - amount, 1.0);

  const filter0 = 0.2126 + 0.7874 * amount;
  const filter1 = 0.7152 - 0.7152 * amount;
  const filter2 = 0.0722 - 0.0722 * amount;
  const filter3 = 0.2126 - 0.2126 * amount;
  const filter4 = 0.7152 + 0.2848 * amount;
  const filter5 = 0.0722 - 0.0722 * amount;
  const filter6 = 0.2126 - 0.2126 * amount;
  const filter7 = 0.7152 - 0.7152 * amount;
  const filter8 = 0.0722 + 0.9278 * amount;

  for (let offset = 0; len > offset; offset += 1) {
    const c = u32[offset];

    const rr = c & 0xff;
    const gg = (c >> 8) & 0xff;
    const bb = (c >> 16) & 0xff;

    const r = clamp(0, (rr * filter0 + gg * filter1 + bb * filter2) | 0, 255);
    const g = clamp(0, (rr * filter3 + gg * filter4 + bb * filter5) | 0, 255);
    const b = clamp(0, (rr * filter6 + gg * filter7 + bb * filter8) | 0, 255);

    u32[offset] = r | (g << 8) | (b << 16) | (c >> 24 << 24);
  }
}

export function grayscale_be(fb, amount) {
  const u32 = to_u32(fb.buffer);
  const len = fb.buffer.length / 4;
  amount = clamp(0.0, 1.0 - amount, 1.0);

  const filter0 = 0.2126 + 0.7874 * amount;
  const filter1 = 0.7152 - 0.7152 * amount;
  const filter2 = 0.0722 - 0.0722 * amount;
  const filter3 = 0.2126 - 0.2126 * amount;
  const filter4 = 0.7152 + 0.2848 * amount;
  const filter5 = 0.0722 - 0.0722 * amount;
  const filter6 = 0.2126 - 0.2126 * amount;
  const filter7 = 0.7152 - 0.7152 * amount;
  const filter8 = 0.0722 + 0.9278 * amount;

  for (let offset = 0; len > offset; offset += 1) {
    const c = u32[offset];

    const rr = (c >> 24) & 0xff;
    const gg = (c >> 16) & 0xff;
    const bb = (c >>  8) & 0xff;

    const r = clamp(0, (rr * filter0 + gg * filter1 + bb * filter2) | 0, 255);
    const g = clamp(0, (rr * filter3 + gg * filter4 + bb * filter5) | 0, 255);
    const b = clamp(0, (rr * filter6 + gg * filter7 + bb * filter8) | 0, 255);

    u32[offset] = (c & 0xff) | (b << 8) | (g << 16) | (r << 24);
  }
}

function init_mod() {
  mod = new WebAssembly.Module(Uint8Array.of(0,97,115,109,1,0,0,0,1,7,1,96,3,127,127,125,0,3,2,1,0,5,3,1,0,1,7,22,2,6,109,101,109,111,114,121,2,0,9,103,114,97,121,115,99,97,108,101,0,0,10,208,5,1,205,5,3,2,127,12,123,10,125,2,64,32,0,32,1,108,34,0,65,2,116,69,13,0,67,0,0,128,63,32,2,147,34,2,67,0,0,128,63,32,2,67,0,0,128,63,93,27,67,0,0,0,0,151,34,2,67,77,132,109,63,148,67,152,221,147,61,146,33,18,32,2,67,78,209,145,62,148,67,89,23,55,63,146,33,19,67,208,179,89,62,32,2,67,208,179,89,62,148,147,33,20,67,152,221,147,61,32,2,67,152,221,147,61,148,147,33,21,67,89,23,55,63,32,2,67,89,23,55,63,148,147,33,22,32,2,67,12,147,73,63,148,67,208,179,89,62,146,33,2,32,0,65,255,255,255,255,3,113,34,0,65,1,32,0,65,1,75,27,34,4,65,4,79,4,64,32,18,253,19,33,7,32,19,253,19,33,8,32,20,253,19,33,9,32,21,253,19,33,10,32,22,253,19,33,11,32,2,253,19,33,12,65,16,33,0,32,4,65,252,255,255,255,3,113,34,3,33,1,3,64,32,0,32,8,32,0,253,0,4,0,34,5,65,8,253,173,1,253,12,255,0,0,0,255,0,0,0,255,0,0,0,255,0,0,0,253,78,253,251,1,34,6,253,230,1,32,9,32,5,253,12,255,0,0,0,255,0,0,0,255,0,0,0,255,0,0,0,253,78,253,251,1,34,13,253,230,1,34,14,253,228,1,32,10,32,5,65,16,253,173,1,253,12,255,0,0,0,255,0,0,0,255,0,0,0,255,0,0,0,253,78,253,251,1,34,15,253,230,1,34,16,253,228,1,253,249,1,253,12,255,0,0,0,255,0,0,0,255,0,0,0,255,0,0,0,253,183,1,65,8,253,171,1,32,11,32,6,253,230,1,34,6,32,12,32,13,253,230,1,253,228,1,32,16,253,228,1,253,249,1,253,12,255,0,0,0,255,0,0,0,255,0,0,0,255,0,0,0,253,183,1,253,80,32,6,32,14,253,228,1,32,7,32,15,253,230,1,253,228,1,253,249,1,253,12,255,0,0,0,255,0,0,0,255,0,0,0,255,0,0,0,253,183,1,65,16,253,171,1,253,80,32,5,253,12,0,0,0,255,0,0,0,255,0,0,0,255,0,0,0,255,253,78,253,80,253,11,4,0,32,0,65,16,106,33,0,32,1,65,4,107,34,1,13,0,11,32,3,32,4,70,13,1,11,32,4,32,3,107,33,4,32,3,65,2,116,65,16,106,33,0,3,64,32,19,32,0,40,2,0,34,1,65,8,118,65,255,1,113,179,34,17,148,32,20,32,1,65,255,1,113,179,34,23,148,34,24,146,32,21,32,1,65,16,118,65,255,1,113,179,34,25,148,34,26,146,252,1,33,3,32,0,32,1,65,128,128,128,120,113,32,3,65,255,1,32,3,65,255,1,73,27,65,8,116,32,22,32,17,148,34,17,32,2,32,23,148,146,32,26,146,252,1,34,1,65,255,1,32,1,65,255,1,73,27,114,32,17,32,24,146,32,18,32,25,148,146,252,1,34,1,65,255,1,32,1,65,255,1,73,27,65,16,116,114,114,54,2,0,32,0,65,4,106,33,0,32,4,65,1,107,34,4,13,0,11,11,11));
}