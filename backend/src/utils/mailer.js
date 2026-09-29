const nodemailer = require('nodemailer');
const config     = require('../config/env');

// port 465 = TLS from the start, 587 = STARTTLS
const transporter = config.smtp.host
  ? nodemailer.createTransport({
    host  : config.smtp.host,
    port  : config.smtp.port,
    secure: config.smtp.port === 465,
    auth  : config.smtp.user ? { user: config.smtp.user, pass: config.smtp.pass } : undefined,
  })
  : null;

const TEXTS = {
  fr: {
    subject: 'Vérifiez votre adresse email',
    hello  : (name) => `Bonjour ${name},`,
    body   : 'Bienvenue sur GardenFlow ! Cliquez sur le lien ci-dessous pour vérifier votre adresse email et pouvoir vous connecter.',
    button : 'Vérifier mon email',
    expiry : 'Ce lien est valable 24 heures. Si vous n\'avez pas créé de compte, ignorez cet email.',
  },
  en: {
    subject: 'Verify your email address',
    hello  : (name) => `Hello ${name},`,
    body   : 'Welcome to GardenFlow! Click the link below to verify your email address and be able to log in.',
    button : 'Verify my email',
    expiry : 'This link is valid for 24 hours. If you did not create an account, ignore this email.',
  },
};

const escapeHtml = (text) => text.replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);

/** Without SMTP configured (development), the email is printed in the terminal so the link can be opened by hand. */
const send = async ({ to, subject, text, html }) => {
  if (!transporter) {
    if (!config.isTest) console.log(`\n📧 Email to ${to} (SMTP_HOST not set, not sent) : ${subject}\n${text}\n`);
    return;
  }
  await transporter.sendMail({ from: config.smtp.from, to, subject, text, html });
};

const mailer = {
  /** lang : 'fr' (default) or 'en' */
  sendVerificationEmail: async ({ to, username, url, lang }) => {
    const t    = TEXTS[lang] || TEXTS.fr;
    const name = escapeHtml(username);

    await send({
      to,
      subject: `GardenFlow - ${t.subject}`,
      text   : `${t.hello(username)}\n\n${t.body}\n\n${url}\n\n${t.expiry}`,
      html   : `
        <div style="font-family: Arial, sans-serif; max-width: 480px; margin: auto; color: #333">
          <h2 style="color: #4CAF50">🌱 GardenFlow</h2>
          <p>${t.hello(name)}</p>
          <p>${t.body}</p>
          <p style="text-align: center; margin: 32px 0">
            <a href="${url}" style="background: #4CAF50; color: #fff; padding: 12px 24px; border-radius: 8px; text-decoration: none; font-weight: bold">${t.button}</a>
          </p>
          <p style="font-size: 12px; color: #888">${t.expiry}</p>
        </div>`,
    });
  },
};

// the functions are read from this object at call time, so the tests can spy on them
module.exports = mailer;
