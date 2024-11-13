const express = require('express');
const router = express.Router();
const redisClient = require('../config/redis');
const { v4: uuidv4 } = require('uuid');

// Fonction pour générer un code de partie unique
function generateSimpleCode(length = 6) {
  const characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let result = '';
  for (let i = 0; i < length; i++) {
    result += characters.charAt(Math.floor(Math.random() * characters.length));
  }
  return result;
}

module.exports = (io) => {
  // Route pour créer une partie
  router.post('/create-game', async (req, res) => {
    const { playerName } = req.body;

    try {
      let gameId;
      do {
        gameId = generateSimpleCode();
      } while (await redisClient.exists(`game:${gameId}`));

      const playerId = uuidv4();

      const gameData = {
        players: JSON.stringify([{ playerId, playerName, ready: false }]),
        status: 'waiting',
      };

      await redisClient.hSet(`game:${gameId}`, 'players', gameData.players, 'status', gameData.status);
      await redisClient.set(`player:${playerId}`, gameId);
      await redisClient.expire(`game:${gameId}`, 300);

      res.json({ gameId, playerId });
    } catch (error) {
      console.error('Erreur lors de la création de la partie:', error);
      res.status(500).json({ error: 'Erreur lors de la création de la partie' });
    }
  });

  // Route pour rejoindre une partie
  router.post('/join-game', async (req, res) => {
    const { gameId, playerName } = req.body;
  
    try {
      const gameExists = await redisClient.exists(`game:${gameId}`);
      if (!gameExists) {
        return res.status(404).json({ error: 'Partie introuvable' });
      }
  
      const playerId = uuidv4();
      const players = JSON.parse(await redisClient.hGet(`game:${gameId}`, 'players')) || [];
      players.push({ playerId, playerName, ready: false });
  
      await redisClient.hSet(`game:${gameId}`, 'players', JSON.stringify(players), 'status', 'active');
      await redisClient.set(`player:${playerId}`, gameId);
      await redisClient.expire(`game:${gameId}`, 3600);
  
      // Envoyer 'currentPlayers' uniquement au nouveau client
      res.json({ playerId, currentPlayers: players });
  
      // Notifier tous les clients du salon sauf le nouveau client
      io.to(gameId).emit('playerJoined', { playerId, playerName });
    } catch (error) {
      console.error('Erreur lors de la connexion à la partie:', error);
      res.status(500).json({ error: 'Erreur lors de la connexion à la partie' });
    }
  });
  

  // Gestion des événements de connexion Socket.IO
  io.on('connection', (socket) => {
    console.log("Un joueur s'est connecté");

    // Gestion de l'événement de rejoindre une salle
    socket.on('joinRoom', (gameId) => {
      socket.join(gameId);
      console.log(`Joueur a rejoint la salle : ${gameId}`);
    });

    socket.on('disconnect', () => {
      console.log("Un joueur s'est déconnecté");
    });
  });

  return router;
};
