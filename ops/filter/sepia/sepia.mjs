import { wasm, simd, clamp, to_u32, endianness } from '../../_.mjs';

let mod = null;
const st = 64 * 1024;
const ceil = Math.ceil;

export default function sepia(fb, amount) {
  const len = fb.buffer.length;
  if (wasm && simd && st < len) return sepia_simd(fb, amount);
  else  return (endianness ? sepia_le : sepia_be)(fb, amount);
}

export function sepia_simd(fb, amount) {
  if (mod === null) init_mod();
  const { sepia, memory } = new WebAssembly.Instance(mod).exports;

  memory.grow(ceil((16 + fb.buffer.length) / 65536));

  const u32 = to_u32(fb.buffer);
  const o32 = new Uint32Array(memory.buffer, 16, u32.length);
  o32.set(u32); sepia(fb.width, fb.height, amount); u32.set(o32);
}

export function sepia_le(fb, amount) {
  const u32 = to_u32(fb.buffer);
  const len = fb.buffer.length / 4;
  amount = clamp(0.0, 1.0 - amount, 1.0);

  const filter0 = 0.393 + 0.607 * amount;
  const filter1 = 0.769 - 0.769 * amount;
  const filter2 = 0.189 - 0.189 * amount;
  const filter3 = 0.349 - 0.349 * amount;
  const filter4 = 0.686 + 0.314 * amount;
  const filter5 = 0.168 - 0.168 * amount;
  const filter6 = 0.272 - 0.272 * amount;
  const filter7 = 0.534 - 0.534 * amount;
  const filter8 = 0.131 + 0.869 * amount;

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

export function sepia_be(fb, amount) {
  const u32 = to_u32(fb.buffer);
  const len = fb.buffer.length / 4;
  amount = clamp(0.0, 1.0 - amount, 1.0);

  const filter0 = 0.393 + 0.607 * amount;
  const filter1 = 0.769 - 0.769 * amount;
  const filter2 = 0.189 - 0.189 * amount;
  const filter3 = 0.349 - 0.349 * amount;
  const filter4 = 0.686 + 0.314 * amount;
  const filter5 = 0.168 - 0.168 * amount;
  const filter6 = 0.272 - 0.272 * amount;
  const filter7 = 0.534 - 0.534 * amount;
  const filter8 = 0.131 + 0.869 * amount;

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
  mod = new WebAssembly.Module(Uint8Array.of(0,97,115,109,1,0,0,0,1,7,1,96,3,127,127,125,0,3,2,1,0,5,3,1,0,1,7,18,2,6,109,101,109,111,114,121,2,0,5,115,101,112,105,97,0,0,10,158,6,1,155,6,3,2,127,13,123,11,125,2,64,32,0,32,1,108,34,0,65,2,116,69,13,0,67,0,0,128,63,32,2,147,34,2,67,0,0,128,63,32,2,67,0,0,128,63,93,27,67,0,0,0,0,151,34,2,67,201,118,94,63,148,67,221,36,6,62,146,33,18,67,57,180,8,63,32,2,67,57,180,8,63,148,147,33,19,67,150,67,139,62,32,2,67,150,67,139,62,148,147,33,20,67,49,8,44,62,32,2,67,49,8,44,62,148,147,33,21,32,2,67,156,196,160,62,148,67,178,157,47,63,146,33,22,67,33,176,178,62,32,2,67,33,176,178,62,148,147,33,23,67,55,137,65,62,32,2,67,55,137,65,62,148,147,33,24,67,47,221,68,63,32,2,67,47,221,68,63,148,147,33,25,32,2,67,90,100,27,63,148,67,76,55,201,62,146,33,2,32,0,65,255,255,255,255,3,113,34,0,65,1,32,0,65,1,75,27,34,4,65,4,79,4,64,32,18,253,19,33,9,32,19,253,19,33,10,32,20,253,19,33,11,32,21,253,19,33,12,32,22,253,19,33,13,32,23,253,19,33,14,32,24,253,19,33,15,32,25,253,19,33,16,32,2,253,19,33,17,65,16,33,0,32,4,65,252,255,255,255,3,113,34,3,33,1,3,64,32,0,32,13,32,0,253,0,4,0,34,5,65,8,253,173,1,253,12,255,0,0,0,255,0,0,0,255,0,0,0,255,0,0,0,253,78,253,251,1,34,6,253,230,1,32,14,32,5,253,12,255,0,0,0,255,0,0,0,255,0,0,0,255,0,0,0,253,78,253,251,1,34,7,253,230,1,253,228,1,32,12,32,5,65,16,253,173,1,253,12,255,0,0,0,255,0,0,0,255,0,0,0,255,0,0,0,253,78,253,251,1,34,8,253,230,1,253,228,1,253,249,1,253,12,255,0,0,0,255,0,0,0,255,0,0,0,255,0,0,0,253,183,1,65,8,253,171,1,32,16,32,6,253,230,1,32,17,32,7,253,230,1,253,228,1,32,15,32,8,253,230,1,253,228,1,253,249,1,253,12,255,0,0,0,255,0,0,0,255,0,0,0,255,0,0,0,253,183,1,253,80,32,10,32,6,253,230,1,32,11,32,7,253,230,1,253,228,1,32,9,32,8,253,230,1,253,228,1,253,249,1,253,12,255,0,0,0,255,0,0,0,255,0,0,0,255,0,0,0,253,183,1,65,16,253,171,1,253,80,32,5,253,12,0,0,0,255,0,0,0,255,0,0,0,255,0,0,0,255,253,78,253,80,253,11,4,0,32,0,65,16,106,33,0,32,1,65,4,107,34,1,13,0,11,32,3,32,4,70,13,1,11,32,4,32,3,107,33,4,32,3,65,2,116,65,16,106,33,0,3,64,32,22,32,0,40,2,0,34,1,65,8,118,65,255,1,113,179,34,26,148,32,23,32,1,65,255,1,113,179,34,27,148,146,32,21,32,1,65,16,118,65,255,1,113,179,34,28,148,146,252,1,33,3,32,0,32,1,65,128,128,128,120,113,32,3,65,255,1,32,3,65,255,1,73,27,65,8,116,32,25,32,26,148,32,2,32,27,148,146,32,24,32,28,148,146,252,1,34,1,65,255,1,32,1,65,255,1,73,27,114,32,19,32,26,148,32,20,32,27,148,146,32,18,32,28,148,146,252,1,34,1,65,255,1,32,1,65,255,1,73,27,65,16,116,114,114,54,2,0,32,0,65,4,106,33,0,32,4,65,1,107,34,4,13,0,11,11,11));
}