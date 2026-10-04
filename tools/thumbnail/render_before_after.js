const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  for (const [mode, w, h] of [['icon', 512, 512], ['thumb', 1920, 1080]]) {
    const page = await browser.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: 1 });
    page.on('pageerror', e => console.log('pageerror', e.message));
    page.on('console', m => { if (m.type() === 'error') console.log('console', m.text()); });
    await page.goto(`http://127.0.0.1:8765/before_after.html?mode=${mode}`);
    await page.waitForSelector('body[data-ready="1"]', { state: 'attached', timeout: 120000 });
    await page.waitForTimeout(500);
    await page.screenshot({ path: `${__dirname}/${mode}2.png`, clip: { x: 0, y: 0, width: w, height: h } });
    console.log('rendered', mode);
  }
  await browser.close();
})();
