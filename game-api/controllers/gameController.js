const { v4: uuidv4 } = require('uuid');
const redisClient = require('../config/redis');
const mapData = require('../models/map');

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
  console.log(`createGame: Requête reçue pour créer une partie. playerName="${playerName}"`);
  try {
    let gameId;
    do {
      gameId = generateGameId();
    } while (await redisClient.exists(`game:${gameId}`));

    console.log(`createGame: Génération d'un nouveau gameId="${gameId}"`);

    const playerId = uuidv4();
    console.log(`createGame: Nouveau playerId="${playerId}" pour le host "${playerName}"`);

    const startingPosition = { x: 7, y: 8 };
    const startingOrientation = 'north';

    const gameData = {
      players: JSON.stringify([
        {
          playerId,
          playerName,
          ready: false,
          isHost: true,
          position: startingPosition,
          orientation: startingOrientation,
        },
      ]),
      activePlayerId: playerId,
      status: 'waiting',
      maze: JSON.stringify(mapData),
    };

    await redisClient.hSet(
      `game:${gameId}`,
      'players',
      gameData.players,
      'activePlayerId',
      gameData.activePlayerId,
      'status',
      gameData.status,
      'maze',
      gameData.maze
    );

    console.log(`createGame: Partie créée avec gameId="${gameId}". Host="${playerName}" (playerId="${playerId}")`);

    res.json({ gameId, playerId });
  } catch (error) {
    console.error('createGame: Erreur lors de la création de la partie:', error);
    res.status(500).json({ error: 'Erreur lors de la création de la partie' });
  }
};

const joinGame = async (req, res) => {
  const { gameId, playerName } = req.body;
  console.log(`joinGame: Requête reçue pour rejoindre gameId="${gameId}" avec playerName="${playerName}"`);
  try {
    const gameData = await redisClient.hGetAll(`game:${gameId}`);
    if (!gameData || !gameData.players) {
      console.error(`joinGame: Aucune partie trouvée avec gameId="${gameId}"`);
      return res.status(404).json({ error: 'Partie introuvable' });
    }

    const players = JSON.parse(gameData.players || '[]');
    const playerId = uuidv4();
    console.log(`joinGame: Nouveau playerId="${playerId}" pour le joueur "${playerName}" rejoignant la partie.`);

    // Position par défaut
    const startingPosition = { x: players.length, y: 0, orientation: 'north' };

    players.push({
      playerId,
      playerName,
      ready: false,
      isHost: false,
      position: startingPosition,
      orientation: startingPosition.orientation,
    });

    await redisClient.hSet(`game:${gameId}`, 'players', JSON.stringify(players));
    console.log(`joinGame: Joueur "${playerName}" (id="${playerId}") ajouté à la partie "${gameId}"`);

    res.json({ playerId });
  } catch (error) {
    console.error('joinGame: Erreur lors de la connexion à la partie:', error);
    res.status(500).json({ error: 'Erreur lors de la connexion à la partie' });
  }
};

const getActivePlayer = async (req, res) => {
  const { gameId } = req.params;
  try {
    const gameData = await redisClient.hGetAll(`game:${gameId}`);
    res.json({ activePlayerId: gameData.activePlayerId });
  } catch (error) {
    res.status(500).json({ error: 'Erreur serveur' });
  }
};

module.exports = {
  createGame,
  joinGame,
  getActivePlayer,
};
