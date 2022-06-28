import { to_u32 } from '../../_.mjs';
import framebuffer from '../../../framebuffer.mjs';

export default matrix;

function invert(a, b, c, d, tx, ty) {
  const dt = 1.0 / (a * d - b * c);

  return [
    d * dt, -c * dt, dt * (c * ty - d * tx),
    -b * dt, a * dt, dt * (b * tx - a * ty),
  ];
}

function point(x, y, xc, yc, matrix) {
  const xa = x - xc;
  const ya = y - yc;
  const ym12 = matrix[2] + ya * matrix[1];
  const ym45 = matrix[5] + ya * matrix[4];
  const xx = (xc + (ym12 + xa * matrix[0])) | 0;
  const yy = (yc + (ym45 + xa * matrix[3])) | 0;

  return [xx, yy];
};



export function scale(x, y) {
  return [x, 0, 0, y ?? x, 0, 0];
}

export function translate(x, y) {
  return [1, 0, 0, 1, x, y || 0];
}

export function skew(x, y = 0) {
  return [1, Math.tan(y * (Math.PI / 180)), Math.tan(x * (Math.PI / 180)), 1, 0, 0];
}

export function rotate(deg) {
  const cos = Math.cos(deg * (Math.PI / 180));
  const sin = Math.sin(deg * (Math.PI / 180));

  return [cos, sin, -sin, cos, 0, 0];
}

export function dot(...matrixes) {
  const base = [1, 0, 0, 1, 0, 0];
  
  for (const matrix of matrixes) {
    const oa = base[0]; const ob = base[1]; const oc = base[2];
    const od = base[3]; const ox = base[4]; const oy = base[5];
    const na = matrix[0]; const nb = matrix[1]; const nc = matrix[2];
    const nd = matrix[3]; const nx = matrix[4]; const ny = matrix[5];

    base[0] = oa * na + oc * nb;
    base[1] = ob * na + od * nb;
    base[2] = oa * nc + oc * nd;
    base[3] = ob * nc + od * nd;
    base[4] = ox + oa * nx + oc * ny;
    base[5] = oy + ob * nx + od * ny;
  }

  return base;
}

export function matrix(fb, a, b, c, d, tx, ty, resize = true) {
  let nfb;
  const w = fb.width;
  const h = fb.height;

  const xc = w / 2;
  const yc = h / 2;

  if (!resize) nfb = framebuffer(w, h);

  else {
    const matrix = [a, c, tx, b, d, ty];
    const [x0, y0] = point(0, 0, xc, yc, matrix);
    const [x1, y1] = point(w, 0, xc, yc, matrix);
    const [x2, y2] = point(0, h, xc, yc, matrix);
    const [x3, y3] = point(w, h, xc, yc, matrix);

    const width = Math.max(x0, x1, x2, x3) - Math.min(x0, x1, x2, x3);
    const height = Math.max(y0, y1, y2, y3) - Math.min(y0, y1, y2, y3);

    nfb = framebuffer(width, height);
  }

  const width = nfb.width;
  const height = nfb.height;
  const o32 = to_u32(fb.buffer);
  const u32 = to_u32(nfb.buffer);

  const {
    0: matrix0, 1: matrix1, 2: matrix2,
    3: matrix3, 4: matrix4, 5: matrix5,
  } = invert(a, b, c, d, tx + (width - w) / 2, ty + (height - h) / 2);

  for (let y = 0; y < height; y += 1) {
    const ya = y - yc;
    const yoffset = y * width;
    const ym12 = matrix2 + ya * matrix1;
    const ym45 = matrix5 + ya * matrix4;

    for (let x = 0; x < width; x += 1) {
      const xa = x - xc;
      const xx = (xc + (ym12 + xa * matrix0)) | 0;
      const yy = (yc + (ym45 + xa * matrix3)) | 0;
      if (0 > xx || 0 > yy || w <= xx || h <= yy) continue;

      u32[x + yoffset] = o32[xx + w * yy];
    }
  }

  return nfb;
}