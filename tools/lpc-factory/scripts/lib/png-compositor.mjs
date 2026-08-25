// png-compositor.mjs — Pure-Node sprite composition using pngjs.
// Loads any PNG (indexed/palette expanded to RGBA), applies palette recolor
// maps (auto-detecting the source ramp), alpha-composites by zPos, and
// assembles final game-ready sheets + JSON frame data.

import fs from "fs";
import path from "path";
import { PNG } from "pngjs";
import { loadPalette, detectSourceColor, getColorRamp, buildRecolorMap } from "./palettes.mjs";

export function loadPngRgba(filePath) {
  return PNG.sync.read(fs.readFileSync(filePath));
}

export function writePng(filePath, width, height, data) {
  const png = new PNG({ width, height });
  data.copy(png.data);
  fs.writeFileSync(filePath, PNG.sync.write(png));
  return filePath;
}

function rgbKey(data, i) {
  return "#" + hex2(data[i]) + hex2(data[i + 1]) + hex2(data[i + 2]);
}
function hex2(n) {
  return n.toString(16).padStart(2, "0");
}

export function applyRecolor(data, recolorMap) {
  if (!recolorMap) return 0;
  let remapped = 0;
  for (let i = 0; i < data.length; i += 4) {
    if (data[i + 3] === 0) continue;
    const target = recolorMap[rgbKey(data, i)];
    if (target) {
      data[i] = parseInt(target.slice(1, 3), 16);
      data[i + 1] = parseInt(target.slice(3, 5), 16);
      data[i + 2] = parseInt(target.slice(5, 7), 16);
      remapped++;
    }
  }
  return remapped;
}

// Apply recolor from a manifest spec:
//   { sourcePaletteFile, targetPaletteFile?, color }
// Detects which native ramp (in the SOURCE/upstream palette) the pixels
// actually use, then maps shade-by-shade onto the target ramp, which lives
// either in the same file or a factory target palette.
export function applyRecolorSpec(data, spec) {
  if (!spec || !spec.sourcePaletteFile || !spec.color) return 0;
  if (!fs.existsSync(spec.sourcePaletteFile)) {
    console.warn("    WARN: palette file missing: " + spec.sourcePaletteFile);
    return 0;
  }
  const sourcePalette = JSON.parse(fs.readFileSync(spec.sourcePaletteFile, "utf8"));
  const sourceName = detectSourceColor(data, sourcePalette);
  if (!sourceName) {
    console.warn("    WARN: no matching source ramp detected");
    return 0;
  }

  let targetPalette = sourcePalette;
  if (spec.targetPaletteFile) {
    if (!fs.existsSync(spec.targetPaletteFile)) {
      console.warn("    WARN: target palette missing: " + spec.targetPaletteFile);
      return 0;
    }
    targetPalette = JSON.parse(fs.readFileSync(spec.targetPaletteFile, "utf8"));
  }
  const targetRamp = targetPalette[spec.color];
  if (!targetRamp) {
    console.warn("    WARN: color \"" + spec.color + "\" not found in target palette" +
      " (" + Object.keys(targetPalette).slice(0, 8).join(", ") + "...)");
    return 0;
  }

  const map = buildRecolorMap(
    getColorRamp(sourcePalette, sourceName),
    targetRamp
  );
  const n = applyRecolor(data, map);
  return n;
}

function drawImageOver(dst, src, ox, oy) {
  for (let y = 0; y < src.height; y++) {
    const dy = oy + y;
    if (dy < 0 || dy >= dst.height) continue;
    for (let x = 0; x < src.width; x++) {
      const dx = ox + x;
      if (dx < 0 || dx >= dst.width) continue;
      const si = (y * src.width + x) * 4;
      const di = (dy * dst.width + dx) * 4;
      const sa = src.data[si + 3];
      if (sa === 0) continue;
      if (sa === 255) {
        dst.data[di] = src.data[si];
        dst.data[di + 1] = src.data[si + 1];
        dst.data[di + 2] = src.data[si + 2];
        dst.data[di + 3] = 255;
      } else {
        const da = dst.data[di + 3];
        const outA = sa + (da * (255 - sa)) / 255;
        if (outA === 0) continue;
        for (let c = 0; c < 3; c++) {
          dst.data[di + c] = Math.round(
            (src.data[si + c] * sa + dst.data[di + c] * da * (255 - sa) / 255) / outA
          );
        }
        dst.data[di + 3] = Math.round(outA);
      }
    }
  }
}

// Compose one animation entry: { animation, frameSize, images: [{zPos,file,recolorSpec?}]}
export function composeAnimation(animEntry, composeDir) {
  let maxW = 0;
  let maxH = 0;
  const loaded = [];
  for (const img of animEntry.images) {
    const png = loadPngRgba(img.file);
    applyRecolorSpec(png.data, img.recolorSpec);
    loaded.push({ zPos: img.zPos, png });
    if (png.width > maxW) maxW = png.width;
    if (png.height > maxH) maxH = png.height;
  }
  loaded.sort((a, b) => a.zPos - b.zPos);
  const canvas = new PNG({ width: maxW, height: maxH });
  for (const l of loaded) drawImageOver(canvas, l.png, 0, 0);
  const outFile = path.join(composeDir, animEntry.animation + ".png");
  writePng(outFile, maxW, maxH, canvas.data);
  const frameSize = animEntry.frameSize || 64;
  return {
    name: animEntry.animation,
    file: outFile,
    frameSize,
    frames: Math.round(maxW / frameSize),
    directions: Math.round(maxH / frameSize),
    canvasW: maxW,
    canvasH: maxH,
  };
}

export function buildSheet(composedList, sheetPng, sheetJson) {
  let maxW = 0;
  let totalH = 0;
  for (const c of composedList) {
    if (c.canvasW > maxW) maxW = c.canvasW;
    totalH += c.canvasH;
  }
  const sheet = new PNG({ width: maxW, height: totalH });
  let yOff = 0;
  const frames = {};
  const animationsMeta = {};
  for (const c of composedList) {
    const img = loadPngRgba(c.file);
    drawImageOver(sheet, img, 0, yOff);
    animationsMeta[c.name] = {
      row: yOff / c.frameSize, y: yOff, frames: c.frames,
      directions: c.directions, frameSize: c.frameSize,
    };
    for (let dir = 0; dir < c.directions; dir++) {
      for (let f = 0; f < c.frames; f++) {
        frames[c.name + "_" + dir + "_" + f] = {
          frame: { x: f * c.frameSize, y: yOff + dir * c.frameSize, w: c.frameSize, h: c.frameSize },
          rotated: false, trimmed: false,
          spriteSourceSize: { x: 0, y: 0, w: c.frameSize, h: c.frameSize },
          sourceSize: { w: c.frameSize, h: c.frameSize },
        };
      }
    }
    yOff += c.canvasH;
  }
  writePng(sheetPng, maxW, totalH, sheet.data);
  if (sheetJson) {
    const meta = {
      app: "notw-lpc-factory",
      image: path.basename(sheetPng),
      format: "RGBA8888",
      size: { w: maxW, h: totalH },
      scale: 1,
      animations: animationsMeta,
    };
    fs.writeFileSync(sheetJson, JSON.stringify({ frames, meta }, null, 1));
  }
  return { sheetPath: sheetPng, jsonPath: sheetJson, width: maxW, height: totalH };
}

export function countOpaque(data) {
  let n = 0;
  for (let i = 3; i < data.length; i += 4) {
    if (data[i] > 0) n++;
  }
  return n;
}
