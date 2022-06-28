export default function framebuffer(width, height, buffer) {
  if (!buffer) buffer = new Uint8Array(4 * width * height);

  else {
    if (!(buffer instanceof Uint8Array)) {
      if (buffer instanceof Array) buffer = new Uint8Array(buffer);
      else if (buffer instanceof ArrayBuffer || buffer instanceof SharedArrayBuffer) buffer = new Uint8Array(buffer);
      else if (ArrayBuffer.isView(buffer)) buffer = new Uint8Array(buffer.buffer, buffer.byteOffset, buffer.byteLength);
      else throw new TypeError('expected buffer to be an instance of Array, ArrayBuffer, ArrayBufferView, or SharedArrayBuffer');
    }

    if (buffer.length !== 4 * width * height) throw new RangeError('buffer length does not match framebuffer dimensions (4 * width * height)');
  }

  return { width, height, buffer };
}