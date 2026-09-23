/**
 * Changes the role of an existing user (there is no public way to become admin).
 *   node scripts/set-role.js <email> <user|admin>
 *   npm run set-role -- me@example.com admin
 */
const db = require('../src/database/db');

const ROLES = ['user', 'admin'];

const main = async () => {
  const [email, role] = process.argv.slice(2);

  if (!email || !ROLES.includes(role)) {
    console.error(`Usage: node scripts/set-role.js <email> <${ROLES.join('|')}>`);
    process.exitCode = 1;
    return;
  }

  const [result] = await db.query('UPDATE user SET role = ? WHERE email = ?', [role, email.trim().toLowerCase()]);

  if (result.affectedRows === 0) {
    console.error(`❌ No user with email ${email}`);
    process.exitCode = 1;
  } else {
    console.log(`✅ ${email} is now ${role}`);
  }
};

main()
  .catch((err) => {
    console.error(`❌ ${err.message}`);
    process.exitCode = 1;
  })
  .finally(() => db.end());
