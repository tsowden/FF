const express = require('express');
const router = express.Router();
const redisClient = require('../config/redis');
const { createGame, joinGame, getActivePlayer } = require('../controllers/gameController');

// Créer une partie
router.post('/create-game', createGame);

// Rejoindre une partie
router.post('/join-game', joinGame);

// Obtenir le joueur actif
router.get('/active-player/:gameId', getActivePlayer);

module.exports = router;
