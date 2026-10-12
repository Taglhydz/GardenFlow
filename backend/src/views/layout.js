/**
 * Web page opened from a link of an email (in the browser, not in the app) : a card in the middle of the screen.
 * No JavaScript : the Content-Security-Policy of helmet forbids inline scripts.
 * title and content must already be escaped.
 */
const layout = ({ lang, title, color, content }) => `<!doctype html>
<html lang="${lang}">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="robots" content="noindex">
  <title>GardenFlow - ${title}</title>
  <style>
    body   { margin: 0; min-height: 100vh; display: flex; align-items: center; justify-content: center;
             background: #FAFAFA; font-family: Arial, sans-serif; color: #333; }
    main   { max-width: 420px; margin: 16px; padding: 32px 24px; background: #fff; border-radius: 16px;
             box-shadow: 0 2px 12px rgba(0, 0, 0, .08); text-align: center; }
    .icon  { font-size: 56px; }
    h1     { color: ${color}; font-size: 24px; }
    p      { line-height: 1.5; }
    .app   { color: #4CAF50; font-weight: bold; margin-top: 24px; }
    form   { text-align: left; }
    label  { display: block; margin: 16px 0 4px; font-weight: bold; }
    input  { box-sizing: border-box; width: 100%; padding: 12px; border: 1px solid #9E9E9E; border-radius: 8px; font-size: 16px; }
    button { width: 100%; margin-top: 24px; padding: 14px; border: 0; border-radius: 8px; background: #4CAF50;
             color: #fff; font-size: 16px; font-weight: bold; cursor: pointer; }
    .hint  { font-size: 13px; color: #616161; }
    .error { color: #F44336; }
  </style>
</head>
<body>
  <main>
    ${content}
    <p class="app">🌱 GardenFlow</p>
  </main>
</body>
</html>`;

module.exports = { layout };
