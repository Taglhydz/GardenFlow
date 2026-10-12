/**
 * Pages opened from the link of the "forgot password" email (in the browser, not in the app) :
 * a form for the new password, then the result.
 */
const { layout } = require('./layout');

const TEXTS = {
  fr: {
    formTitle   : 'Nouveau mot de passe',
    formText    : 'Choisissez le nouveau mot de passe de votre compte GardenFlow.',
    password    : 'Nouveau mot de passe',
    confirm     : 'Confirmez le mot de passe',
    rules       : 'Au moins 10 caractères, avec une minuscule, une majuscule, un chiffre et un symbole.',
    submit      : 'Changer mon mot de passe',
    errors      : {
      weak    : 'Ce mot de passe ne respecte pas les règles ci-dessous.',
      mismatch: 'Les deux mots de passe sont différents.',
    },
    password_changed: { icon: '✅', title: 'Mot de passe changé', text: 'Votre mot de passe est changé. Connectez-vous dans l\'application GardenFlow avec ce nouveau mot de passe.' },
    expired         : { icon: '⏳', title: 'Lien expiré'        , text: 'Ce lien n\'est plus valable. Refaites la demande avec « Mot de passe oublié ? » sur l\'écran de connexion de l\'application.' },
    invalid         : { icon: '❌', title: 'Lien invalide'      , text: 'Ce lien n\'est pas valable ou a déjà servi. Utilisez le lien du dernier email reçu, ou refaites la demande depuis l\'application.' },
  },
  en: {
    formTitle   : 'New password',
    formText    : 'Choose the new password of your GardenFlow account.',
    password    : 'New password',
    confirm     : 'Confirm the password',
    rules       : 'At least 10 characters, with a lowercase letter, an uppercase letter, a digit and a symbol.',
    submit      : 'Change my password',
    errors      : {
      weak    : 'This password does not follow the rules below.',
      mismatch: 'The two passwords are different.',
    },
    password_changed: { icon: '✅', title: 'Password changed', text: 'Your password is changed. Log in to the GardenFlow app with this new password.' },
    expired         : { icon: '⏳', title: 'Link expired'    , text: 'This link is no longer valid. Ask again with "Forgot password?" on the login screen of the app.' },
    invalid         : { icon: '❌', title: 'Invalid link'    , text: 'This link is not valid or was already used. Use the link of the last email received, or ask again from the app.' },
  },
};

const texts = (lang) => TEXTS[lang] || TEXTS.fr;

/**
 * Form posted to POST /auth/reset-password.
 * token : the token of the link (64 hex characters, checked before), error : 'weak' | 'mismatch' | undefined
 */
const resetPasswordForm = (token, lang, error) => {
  const t = texts(lang);

  return layout({
    lang,
    title  : t.formTitle,
    color  : '#4CAF50',
    content: `<div class="icon">🔑</div>
    <h1>${t.formTitle}</h1>
    <p>${t.formText}</p>
    ${error ? `<p class="error">${t.errors[error]}</p>` : ''}
    <form method="post" action="reset-password">
      <input type="hidden" name="token" value="${token}">
      <label for="password">${t.password}</label>
      <input id="password" name="password" type="password" autocomplete="new-password" required minlength="10" maxlength="72">
      <p class="hint">${t.rules}</p>
      <label for="password_confirm">${t.confirm}</label>
      <input id="password_confirm" name="password_confirm" type="password" autocomplete="new-password" required maxlength="72">
      <button type="submit">${t.submit}</button>
    </form>`,
  });
};

/** status : 'password_changed' | 'expired' | 'invalid' */
const resetPasswordResult = (status, lang) => {
  const t = texts(lang)[status];

  return layout({
    lang,
    title  : t.title,
    color  : status === 'password_changed' ? '#4CAF50' : '#F44336',
    content: `<div class="icon">${t.icon}</div>
    <h1>${t.title}</h1>
    <p>${t.text}</p>`,
  });
};

module.exports = { resetPasswordForm, resetPasswordResult };
