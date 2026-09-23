/**
 * Builds the SET clause of a partial UPDATE : only the fields present in `data`
 * (and whitelisted in `allowedFields`) are updated, the others keep their value.
 *
 * buildUpdateSet({ name: 'A', location: undefined }, ['name', 'location'])
 *   => { clause: '`name` = ?', values: ['A'] }
 */
const buildUpdateSet = (data, allowedFields) => {
  const entries = Object.entries(data).filter(([key, value]) => allowedFields.includes(key) && value !== undefined);

  return {
    clause: entries.map(([key]) => `\`${key}\` = ?`).join(', '),
    values: entries.map(([, value]) => value),
  };
};

module.exports = { buildUpdateSet };
