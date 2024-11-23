const { v4: uuidv4 } = require('uuid');
const redisClient = require('../config/redis');

// Fonction pour générer un code de partie unique
function generateGameId(length = 6) {
  const characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let result = '';
  for (let i = 0; i < length; i++) {
    result += characters.charAt(Math.floor(Math.random() * characters.length));
  }
  return result;
}

const createGame = async (req, res) => {
  const { playerName } = req.body;
  console.log(`Backend: Reçu demande de création de partie pour le joueur : ${playerName}`);
  try {
    let gameId;
    do {
      gameId = generateGameId();
    } while (await redisClient.exists(`game:${gameId}`));

    const playerId = uuidv4();
    const gameData = {
      players: JSON.stringify([
        { playerId, playerName, ready: false, isHost: true },
      ]),
      activePlayerId: playerId,
      status: 'waiting',
    };

    await redisClient.hSet(
      `game:${gameId}`,
      'players',
      gameData.players,
      'activePlayerId',
      gameData.activePlayerId,
      'status',
      gameData.status
    );

    console.log(`Backend: Partie créée avec gameId ${gameId} et playerId ${playerId}`);

    res.json({ gameId, playerId });
  } catch (error) {
    console.error('Backend: Erreur lors de la création de la partie:', error);
    res.status(500).json({ error: 'Erreur lors de la création de la partie' });
  }
};

const joinGame = async (req, res) => {
  const io = req.io; // Récupération de io depuis req
  const { gameId, playerName } = req.body;

  console.log(`Backend: Demande de rejoindre la partie ${gameId} par ${playerName}`);

  try {
    if (!(await redisClient.exists(`game:${gameId}`))) {
      if (!res.headersSent) {
        return res.status(404).json({ error: 'Partie introuvable' });
      }
    }

    const playerId = uuidv4();
    const gameData = await redisClient.hGetAll(`game:${gameId}`);
    const players = JSON.parse(gameData.players || '[]');
    players.push({ playerId, playerName, ready: false });

    await redisClient.hSet(`game:${gameId}`, 'players', JSON.stringify(players));
    if (!res.headersSent) {
      res.json({ playerId });
    }

    console.log(`Backend: ${playerName} a rejoint la partie ${gameId}`);

    // Diffuser la liste des joueurs à tous les membres de la salle
    const updatedPlayers = JSON.parse(
      await redisClient.hGet(`game:${gameId}`, 'players')
    );
    io.to(gameId).emit('currentPlayers', updatedPlayers);
  } catch (error) {
    console.error('Backend: Erreur lors de la connexion à la partie:', error);
    if (!res.headersSent) {
      res.status(500).json({ error: 'Erreur lors de la connexion à la partie' });
    }
  }
};

const getActivePlayer = async (req, res) => {
  const { gameId } = req.params;

  console.log(`Backend: Requête pour obtenir le joueur actif de la partie ${gameId}`);

  try {
    const gameData = await redisClient.hGetAll(`game:${gameId}`);
    if (!gameData) return res.status(404).json({ error: 'Game not found' });

    res.json({ activePlayerId: gameData.activePlayerId });
  } catch (error) {
    console.error('Backend: Erreur lors de la récupération du joueur actif:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
};

// Fonction pour changer le joueur actif
const changeActivePlayer = async (gameId, io) => {
  try {
    const gameData = await redisClient.hGetAll(`game:${gameId}`);
    if (!gameData) return;

    const players = JSON.parse(gameData.players || '[]');
    let currentIndex = players.findIndex(
      (p) => p.playerId === gameData.activePlayerId
    );

    // Passer au joueur suivant
    currentIndex = (currentIndex + 1) % players.length;
    const newActivePlayerId = players[currentIndex].playerId;

    // Mettre à jour Redis
    await redisClient.hSet(`game:${gameId}`, 'activePlayerId', newActivePlayerId);

    // Notifier les joueurs
    console.log(
      `Backend: Joueur actif changé pour la partie ${gameId} : ${players[currentIndex].playerName}`
    );
    io.to(gameId).emit('activePlayerChanged', {
      activePlayerId: newActivePlayerId,
      activePlayerName: players[currentIndex].playerName,
    });
  } catch (error) {
    console.error('Backend: Erreur lors du changement de joueur actif:', error);
  }
};

// Gestion des événements Socket.IO
const handleSocketEvents = (io, socket) => {
  console.log('Backend: Socket.IO: Nouveau joueur connecté');

  socket.on('joinRoom', async (gameId) => {
    socket.join(gameId);
    console.log(`Backend: Socket ${socket.id} a rejoint la salle ${gameId}`);

    try {
      const gameData = await redisClient.hGetAll(`game:${gameId}`);
      const players = JSON.parse(gameData.players || '[]');

      console.log(`Backend: Envoi de la liste des joueurs de la partie ${gameId}`);

      io.to(gameId).emit('currentPlayers', players);
    } catch (error) {
      console.error('Backend: Erreur lors de la récupération des joueurs:', error);
    }
  });

  socket.on('playerReady', async ({ gameId, playerName, isReady }) => {
    console.log(`Backend: Mise à jour du statut prêt pour ${playerName} dans la partie ${gameId} : ${isReady}`);
    try {
      const gameData = await redisClient.hGetAll(`game:${gameId}`);
      const players = JSON.parse(gameData.players || '[]');
      const player = players.find((p) => p.playerName === playerName);
      if (player) {
        player.ready = isReady;
        await redisClient.hSet(`game:${gameId}`, 'players', JSON.stringify(players));

        // Informer tous les joueurs de la mise à jour du statut
        io.to(gameId).emit('readyStatusUpdate', { playerName, isReady });

        // Vérifier si tous les joueurs sont prêts
        const allReady = players.every((p) => p.ready);
        if (allReady) {
          console.log(`Backend: Tous les joueurs sont prêts dans la partie ${gameId}`);
          io.to(gameId).emit('allPlayersReady');
        }
      }
    } catch (error) {
      console.error(
        'Backend: Erreur lors de la mise à jour de l\'état "Prêt" du joueur:',
        error
      );
    }
  });

  socket.on('endTurn', async (gameId) => {
    console.log(`Backend: Fin du tour reçu pour la partie ${gameId}`);
    await changeActivePlayer(gameId, io);
  });

  socket.on('startGame', async ({ gameId }) => {
    console.log(`Backend: Demande de démarrage du jeu pour la partie ${gameId}`);
    try {
      const gameData = await redisClient.hGetAll(`game:${gameId}`);
      const players = JSON.parse(gameData.players || '[]');

      if (players.length === 0) {
        console.error(`Backend: Aucun joueur trouvé pour le jeu ${gameId}`);
        return;
      }

      const firstPlayer = players[0];
      await redisClient.hSet(
        `game:${gameId}`,
        'activePlayerId',
        firstPlayer.playerId
      );

      console.log(
        `Backend: Premier joueur actif défini : ${firstPlayer.playerName} (ID: ${firstPlayer.playerId})`
      );

      io.to(gameId).emit('startGame', { activePlayerName: firstPlayer.playerName });
      io.to(gameId).emit('activePlayerChanged', {
        activePlayerId: firstPlayer.playerId,
        activePlayerName: firstPlayer.playerName,
      });
    } catch (error) {
      console.error(`Backend: Erreur lors du démarrage du jeu pour ${gameId} :`, error);
    }
  });

  socket.on('getActivePlayer', async (gameId) => {
    console.log(`Backend: Reçu demande de getActivePlayer pour la partie ${gameId}`);
    try {
      const gameData = await redisClient.hGetAll(`game:${gameId}`);
      if (!gameData || !gameData.activePlayerId) {
        console.error(
          `Backend: Aucune donnée de partie ou joueur actif trouvé pour le jeu ${gameId}`
        );
        socket.emit('activePlayer', { activePlayerName: null });
        return;
      }

      const players = JSON.parse(gameData.players || '[]');
      const activePlayerId = gameData.activePlayerId;
      const activePlayer = players.find((p) => p.playerId === activePlayerId);

      if (activePlayer) {
        console.log(`Backend: Joueur actif pour le jeu ${gameId} : ${activePlayer.playerName}`);
        socket.emit('activePlayer', { activePlayerName: activePlayer.playerName });
      } else {
        console.error(`Backend: Aucun joueur actif trouvé pour le jeu ${gameId}`);
        socket.emit('activePlayer', { activePlayerName: null });
      }
    } catch (error) {
      console.error('Backend: Erreur lors de la récupération du joueur actif :', error);
      socket.emit('activePlayer', { activePlayerName: null });
    }
  });

  socket.on('disconnect', () => {
    console.log('Backend: Socket.IO: Un joueur s\'est déconnecté');
    // Gérer la déconnexion si nécessaire
  });
};

module.exports = {
  createGame,
  joinGame,
  getActivePlayer,
  handleSocketEvents,
};
