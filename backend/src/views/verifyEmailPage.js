/**
 * Page opened from the link of the verification email or of the email change (in the browser, not in the app).
 * Once the address is verified, the same link only shows that it is verified.
 */
const { layout } = require('./layout');

const TEXTS = {
  fr: {
    verified        : { icon: '✅', title: 'Email vérifié !'          , text: 'Votre adresse email est vérifiée. Vous pouvez maintenant vous connecter dans l\'application GardenFlow.' },
    already_verified: { icon: '✅', title: 'Email déjà vérifié'       , text: 'Votre adresse email est vérifiée. Vous pouvez vous connecter dans l\'application GardenFlow.' },
    expired         : { icon: '⏳', title: 'Lien expiré'              , text: 'Ce lien n\'est plus valable. Essayez de vous connecter dans l\'application pour recevoir un nouvel email.' },
    invalid         : { icon: '❌', title: 'Lien invalide'            , text: 'Ce lien n\'est pas valable. Utilisez le lien du dernier email reçu, ou connectez-vous dans l\'application pour en recevoir un nouveau.' },
    email_changed   : { icon: '✅', title: 'Adresse email modifiée'   , text: 'Votre nouvelle adresse email est confirmée. Utilisez-la pour vous connecter dans l\'application GardenFlow.' },
    change_expired  : { icon: '⏳', title: 'Lien expiré'              , text: 'Ce lien n\'est plus valable. Votre adresse email n\'a pas changé : refaites la demande depuis votre profil dans l\'application.' },
    email_taken     : { icon: '❌', title: 'Adresse déjà utilisée'    , text: 'Un autre compte utilise maintenant cette adresse. Votre adresse email n\'a pas changé.' },
  },
  en: {
    verified        : { icon: '✅', title: 'Email verified!'          , text: 'Your email address is verified. You can now log in to the GardenFlow app.' },
    already_verified: { icon: '✅', title: 'Email already verified'   , text: 'Your email address is verified. You can log in to the GardenFlow app.' },
    expired         : { icon: '⏳', title: 'Link expired'             , text: 'This link is no longer valid. Try to log in to the app to receive a new email.' },
    invalid         : { icon: '❌', title: 'Invalid link'             , text: 'This link is not valid. Use the link of the last email received, or log in to the app to receive a new one.' },
    email_changed   : { icon: '✅', title: 'Email address changed'    , text: 'Your new email address is confirmed. Use it to log in to the GardenFlow app.' },
    change_expired  : { icon: '⏳', title: 'Link expired'             , text: 'This link is no longer valid. Your email address has not changed: ask again from your profile in the app.' },
    email_taken     : { icon: '❌', title: 'Address already in use'   , text: 'Another account now uses this address. Your email address has not changed.' },
  },
};

const isSuccess = (status) => ['verified', 'already_verified', 'email_changed'].includes(status);

/**
 * status : 'verified' | 'already_verified' | 'expired' | 'invalid' (verifyToken)
 *       or 'email_changed' | 'change_expired' | 'email_taken' | 'invalid' (confirmEmailChange)
 * lang : 'fr' | 'en'
 */
const verifyEmailPage = (status, lang) => {
  const t = (TEXTS[lang] || TEXTS.fr)[status];

  return layout({
    lang,
    title  : t.title,
    color  : isSuccess(status) ? '#4CAF50' : '#F44336',
    content: `<div class="icon">${t.icon}</div>
    <h1>${t.title}</h1>
    <p>${t.text}</p>`,
  });
};

module.exports = { verifyEmailPage, isSuccess };
