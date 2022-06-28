export function clamp(l, x, h) { return x < l ? l : x > h ? h : x; }
export const endianness = 0x22 === new Uint8Array(new Uint16Array([0x1122]).buffer)[0];
export function to_u32(u8) { return new Uint32Array(u8.buffer, u8.byteOffset, u8.byteLength / 4); }
export const simd = WebAssembly.validate(Uint8Array.of(0,97,115,109,1,0,0,0,1,5,1,96,0,1,123,3,2,1,0,10,10,1,8,0,65,0,253,15,253,98,11));
export const wasm = !(() => { try { new WebAssembly.Module(Uint8Array.of(0,97,115,109,1,0,0,0,5,3,1,0,1,7,10,1,6,109,101,109,111,114,121,2,0)); } catch { return 1; } })();