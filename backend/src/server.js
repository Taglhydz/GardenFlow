const app    = require('./app');
const config = require('./config/env');

app.listen(config.port, () => {
  console.log(`🌱 GardenFlow Server running on port ${config.port} (${config.NODE_ENV})`);
  console.log(`📍 API available at http://localhost:${config.port}/api`);
});
