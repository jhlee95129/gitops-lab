const express = require('express');
const app = express();
app.get('/api/health', (_, res) => res.json({ status: 'ok' }));
app.get('/api/version', (_, res) => res.json({ version: process.env.APP_VERSION || 'dev' }));
app.listen(4000, () => console.log('api on :4000'));
