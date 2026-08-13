import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { Resvg } from '@resvg/resvg-js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '..');
const svgPath = path.join(root, 'assets/image/Fitbuddyai.svg');
const svg = fs.readFileSync(svgPath);

function renderSvg(width) {
  return new Resvg(svg, {
    fitTo: { mode: 'width', value: width },
    background: 'rgba(0,0,0,0)',
  })
    .render()
    .asPng();
}

/** Fit full logo inside Android 12 circular safe zone (~66% of canvas). */
function makeAndroid12Icon(size, fillBg = null) {
  const { Resvg: R } = requireCompatible();
  // Android 12 masks to a circle; safe zone is ~2/3 diameter.
  // Fit the full wordmark inside that circle (corners included).
  const logoW = Math.round(size * 0.52);
  const logoPng = new R(svg, {
    fitTo: { mode: 'width', value: logoW },
    background: 'rgba(0,0,0,0)',
  })
    .render()
    .asPng();

  // Composite onto square via a tiny SVG wrapper.
  const logoB64 = Buffer.from(logoPng).toString('base64');
  const bg =
    fillBg == null
      ? ''
      : `<rect width="${size}" height="${size}" fill="${fillBg}"/>`;
  const wrap = `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"
  width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">
  ${bg}
  <image href="data:image/png;base64,${logoB64}"
    x="${(size - logoW) / 2}" y="${(size - logoW * (262 / 348)) / 2}"
    width="${logoW}" height="${logoW * (262 / 348)}"
    preserveAspectRatio="xMidYMid meet"/>
</svg>`;
  return new R(Buffer.from(wrap), {
    fitTo: { mode: 'width', value: size },
  })
    .render()
    .asPng();
}

function requireCompatible() {
  return { Resvg };
}

function write(file, buf) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, buf);
  console.log('wrote', path.relative(root, file), `(${buf.length} bytes)`);
}

const densities = {
  mdpi: 1,
  hdpi: 1.5,
  xhdpi: 2,
  xxhdpi: 3,
  xxxhdpi: 4,
};

// Pre-Android 12 / window splash: full logo ~280dp wide.
const baseLogoDp = 280;
for (const [name, scale] of Object.entries(densities)) {
  const w = Math.round(baseLogoDp * scale);
  const png = renderSvg(w);
  write(
    path.join(root, `android/app/src/main/res/drawable-${name}/splash_logo.png`),
    png,
  );
  write(
    path.join(
      root,
      `android/app/src/main/res/drawable-night-${name}/splash_logo.png`,
    ),
    png,
  );
}

// Android 12+ center icon: square, full Fitbuddyai.svg inside safe zone.
const baseA12Dp = 288;
for (const [name, scale] of Object.entries(densities)) {
  const size = Math.round(baseA12Dp * scale);
  const png = makeAndroid12Icon(size);
  write(
    path.join(
      root,
      `android/app/src/main/res/drawable-${name}/splash_logo_android12.png`,
    ),
    png,
  );
  write(
    path.join(
      root,
      `android/app/src/main/res/drawable-night-${name}/splash_logo_android12.png`,
    ),
    png,
  );
}

// Remove branding usage — keep files as 1x1 transparent so leftover refs don't break.
const emptySvg = `<?xml version="1.0"?><svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"/>`;
const emptyPng = new Resvg(Buffer.from(emptySvg)).render().asPng();
for (const [name] of Object.entries(densities)) {
  write(
    path.join(
      root,
      `android/app/src/main/res/drawable-${name}/splash_branding.png`,
    ),
    emptyPng,
  );
  write(
    path.join(
      root,
      `android/app/src/main/res/drawable-night-${name}/splash_branding.png`,
    ),
    emptyPng,
  );
}

// Shared Flutter assets
write(path.join(root, 'assets/image/logo_splash.png'), renderSvg(1120));
write(path.join(root, 'assets/image/Fitbuddyai.png'), renderSvg(800));

// iOS SplashLogo imageset (280pt base, aspect ~348:262)
const iosSizes = [
  ['SplashLogo.png', 280],
  ['SplashLogo@2x.png', 560],
  ['SplashLogo@3x.png', 840],
  ['SplashLogoDark.png', 280],
  ['SplashLogoDark@2x.png', 560],
  ['SplashLogoDark@3x.png', 840],
];
for (const [name, w] of iosSizes) {
  write(
    path.join(
      root,
      'ios/Runner/Assets.xcassets/SplashLogo.imageset',
      name,
    ),
    renderSvg(w),
  );
}

console.log('done');
