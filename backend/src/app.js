require('dotenv').config();
const express = require('express');
const app = express();
const routes = require('./routes');
const { logRequest } = require('./utils/logger');

app.use(express.json());

// logger
app.use(logRequest);

// the routes
app.use('/api', routes);

// Management route not found
app.use((req, res) => {
  res.status(404).json({ message: 'Route not found' });
});

// Global error handler
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(err.status || 500).json({
    message: err.message || 'Internal Server Error',
    error: process.env.NODE_ENV === 'development' ? err : {}
  });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🌱 GardenFlow Server running on port ${PORT}`);
  console.log(`📍 API available at http://localhost:${PORT}/api`);
});
