const express = require('express');
const app = express();
const gameRoutes = require('./routes/gameRoutes');
const questionRoutes = require('./routes/questionRoutes');

app.use(express.json());

app.use('/api/game', gameRoutes);
app.use('/api/question', questionRoutes);

module.exports = app;
