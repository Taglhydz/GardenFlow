/**
 * Page opened from the link of the verification email (in the browser, not in the app).
 * Once the address is verified, the same link only shows that it is verified.
 */
const TEXTS = {
  fr: {
    verified        : { icon: '✅', title: 'Email vérifié !'          , text: 'Votre adresse email est vérifiée. Vous pouvez maintenant vous connecter dans l\'application GardenFlow.' },
    already_verified: { icon: '✅', title: 'Email déjà vérifié'       , text: 'Votre adresse email est vérifiée. Vous pouvez vous connecter dans l\'application GardenFlow.' },
    expired         : { icon: '⏳', title: 'Lien expiré'              , text: 'Ce lien n\'est plus valable. Essayez de vous connecter dans l\'application pour recevoir un nouvel email.' },
    invalid         : { icon: '❌', title: 'Lien invalide'            , text: 'Ce lien n\'est pas valable. Utilisez le lien du dernier email reçu, ou connectez-vous dans l\'application pour en recevoir un nouveau.' },
  },
  en: {
    verified        : { icon: '✅', title: 'Email verified!'          , text: 'Your email address is verified. You can now log in to the GardenFlow app.' },
    already_verified: { icon: '✅', title: 'Email already verified'   , text: 'Your email address is verified. You can log in to the GardenFlow app.' },
    expired         : { icon: '⏳', title: 'Link expired'             , text: 'This link is no longer valid. Try to log in to the app to receive a new email.' },
    invalid         : { icon: '❌', title: 'Invalid link'             , text: 'This link is not valid. Use the link of the last email received, or log in to the app to receive a new one.' },
  },
};

/** status : 'verified' | 'already_verified' | 'expired' | 'invalid', lang : 'fr' | 'en' */
const verifyEmailPage = (status, lang) => {
  const t = (TEXTS[lang] || TEXTS.fr)[status];
  const color = status === 'verified' || status === 'already_verified' ? '#4CAF50' : '#F44336';

  return `<!doctype html>
<html lang="${lang}">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="robots" content="noindex">
  <title>GardenFlow - ${t.title}</title>
  <style>
    body  { margin: 0; min-height: 100vh; display: flex; align-items: center; justify-content: center;
            background: #FAFAFA; font-family: Arial, sans-serif; color: #333; }
    main  { max-width: 420px; margin: 16px; padding: 32px 24px; background: #fff; border-radius: 16px;
            box-shadow: 0 2px 12px rgba(0, 0, 0, .08); text-align: center; }
    .icon { font-size: 56px; }
    h1    { color: ${color}; font-size: 24px; }
    p     { line-height: 1.5; }
    .app  { color: #4CAF50; font-weight: bold; margin-top: 24px; }
  </style>
</head>
<body>
  <main>
    <div class="icon">${t.icon}</div>
    <h1>${t.title}</h1>
    <p>${t.text}</p>
    <p class="app">🌱 GardenFlow</p>
  </main>
</body>
</html>`;
};

module.exports = { verifyEmailPage };
