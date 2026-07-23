const puppeteer = require('puppeteer-core');
const fs = require('fs');
const path = require('path');

const url = process.env.STORE_URL || 'http://127.0.0.1:8093';
// Build with: flutter build web -t lib/demo_game.dart --no-tree-shake-icons
const outDir = process.env.STORE_OUT || path.resolve(__dirname, '../../screenshots');
const chrome = process.env.CHROME || '/usr/bin/google-chrome';

const viewports = [
  [360, 800],
  [390, 844],
  [412, 915],
  [430, 932],
  [508, 1035],
];

(async () => {
  fs.mkdirSync(outDir, { recursive: true });
  const browser = await puppeteer.launch({
    executablePath: chrome,
    headless: 'new',
    args: ['--no-sandbox', '--window-size=508,1035'],
  });

  for (const [w, h] of viewports) {
    const page = await browser.newPage();
    await page.setViewport({ width: w, height: h, deviceScaleFactor: 2 });
    await page.goto(url, { waitUntil: 'load', timeout: 60000 });
    await page.waitForFunction(
      () => document.querySelector('flt-glass-pane') || document.querySelector('canvas'),
      { timeout: 90000 },
    );
    await new Promise((r) => setTimeout(r, 5000));
    // Hide Flutter web's native white text-editing overlay before capture.
    await page.evaluate(() => {
      const hide = (root) => {
        try {
          root.querySelectorAll('input,textarea').forEach((el) => {
            el.style.setProperty('opacity', '0', 'important');
            el.style.setProperty('background', 'transparent', 'important');
            el.style.setProperty('background-color', 'transparent', 'important');
            el.style.setProperty('color', 'transparent', 'important');
          });
          root.querySelectorAll('*').forEach((el) => {
            if (el.shadowRoot) hide(el.shadowRoot);
          });
        } catch (_) {}
      };
      hide(document);
    });
    const file = path.join(outDir, `match-word-studio-${w}x${h}.png`);
    await page.screenshot({ path: file, type: 'png' });
    console.log('wrote', file);
    await page.close();
  }

  const updated = path.join(outDir, 'match-word-studio-updated.png');
  fs.copyFileSync(path.join(outDir, 'match-word-studio-508x1035.png'), updated);
  console.log('wrote', updated);

  const dest = path.resolve(outDir, '../docs/screenshots/store/full-journey/11_play_kickoff.png');
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  fs.copyFileSync(updated, dest);
  console.log('copied', dest);

  await browser.close();
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
