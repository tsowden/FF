const { v4: uuidv4 } = require('uuid');
const redisClient = require('../config/redis');
const db = require('../config/db');
const mapData = require('../models/map');


// Fonction pour générer un code de partie unique
function generateGameId(length = 6) {
  const characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let result = '';
  for (let i = 0; i < length; i++) {
    result += characters.charAt(Math.floor(Math.random() * characters.length));
  }
  return result;
}

// Fonction pour récupérer une carte aléatoire
function getRandomCard() {
  return new Promise((resolve, reject) => {
    db.query('SELECT * FROM cards ORDER BY RAND() LIMIT 1', (error, results) => {
      if (error) {
        console.error('Erreur lors de la récupération de la carte:', error);
        reject(error);
      } else {
        resolve(results[0]); // Retourne la première (et seule) carte
      }
    });
  });
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

    // Position & orientation de départ
    const startingPosition = { x: 7, y: 8};
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

    // Assignez des positions de départ basées sur le nombre de joueurs
    const startingPositions = [
      { x: 2, y: 0, orientation: 'south' },
      { x: 0, y: 8, orientation: 'east' },
      // Ajoutez plus de positions de départ si nécessaire
    ];
    const positionIndex = players.length % startingPositions.length;
    const startingPosition = startingPositions[positionIndex];

    players.push({
      playerId,
      playerName,
      ready: false,
      isHost: false,
      position: { x: startingPosition.x, y: startingPosition.y },
      orientation: startingPosition.orientation,
    });

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

const changeActivePlayer = async (gameId, io) => {
  try {
    const gameData = await redisClient.hGetAll(`game:${gameId}`);
    if (!gameData) {
      console.error(`Backend: Game ${gameId} introuvable dans Redis.`);
      return;
    }

    const players = JSON.parse(gameData.players || '[]');
    let currentIndex = players.findIndex(
      (p) => p.playerId === gameData.activePlayerId
    );

    if (currentIndex === -1) {
      console.error(`Backend: Joueur actif introuvable pour la partie ${gameId}.`);
      return;
    }

    // Passer au joueur suivant
    currentIndex = (currentIndex + 1) % players.length;
    const newActivePlayer = players[currentIndex];

    // Mettre à jour Redis avec le nouveau joueur actif
    await redisClient.hSet(`game:${gameId}`, 'activePlayerId', newActivePlayer.playerId);

    // Convertir la position en format alphanumérique
    const { x, y } = newActivePlayer.position;
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const formattedPosition = `${alphabet[x]}${y + 1}`; // Convertir x en lettre et y en coordonnée humaine

    console.log(
      `Backend: Nouveau joueur actif pour la partie ${gameId} : ${newActivePlayer.playerName}, Position : ${formattedPosition}`
    );

    // Récupérer une carte aléatoire
    const card = await getRandomCard();

    // Préparer les descriptions des cartes
    const cardDescriptionPassive = card.card_description_passif.replace(
      '{activePlayerName}',
      newActivePlayer.playerName
    );

    // Diffuser les données du joueur actif et de la carte à tous les clients
    io.to(gameId).emit('activePlayerChanged', {
      activePlayerId: newActivePlayer.playerId,
      activePlayerName: newActivePlayer.playerName,
      cardDescription: card.card_description,
      cardDescriptionPassive: cardDescriptionPassive,
      cardImage: card.card_image,
      cardName: card.card_name,
      position: formattedPosition, // Inclure la position formatée
    });
  } catch (error) {
    console.error('Backend: Erreur lors du changement de joueur actif:', error);
  }
};


// Fonction pour avoir une position plus claire de type A1, J10 etc
function getPositionLabel(x, y) {
  const letters = 'ABCDEFGHIJKLMNOP'; 
  return `${letters[x] || '?'}${y + 1}`;
}


function processPlayerMove(player, move, maze) {
  let { x, y } = player.position;
  let orientation = player.orientation;

  const orientations = ['north', 'east', 'south', 'west'];
  const idx = orientations.indexOf(orientation);

  const movementOffsets = {
    'north': { dx: 0, dy: -1 },
    'east': { dx: 1, dy: 0 },
    'south': { dx: 0, dy: 1 },
    'west': { dx: -1, dy: 0 },
  };

  if (move === 'forward') {
    const offset = movementOffsets[orientation];
    const newX = x + offset.dx;
    const newY = y + offset.dy;

    if (
      newY >= 0 &&
      newY < maze.length &&
      newX >= 0 &&
      newX < maze[0].length &&
      maze[newY][newX].accessible
    ) {
      player.position = { x: newX, y: newY };
      const newPositionLabel = getPositionLabel(newX, newY);
      console.log(`Backend: Player moved forward to position ${newPositionLabel} (${newX}, ${newY}), orientation: ${orientation}`);
      return { success: true };
    } else {
      return { success: false, message: 'Impossible d\'avancer; chemin bloqué' };
    }
  } else if (move === 'left' || move === 'right') {
    let newIdx = idx;
    if (move === 'left') {
      newIdx = (idx + 3) % 4; // Tourner à gauche
    } else if (move === 'right') {
      newIdx = (idx + 1) % 4; // Tourner à droite
    }
    const newOrientation = orientations[newIdx];
    const offset = movementOffsets[newOrientation];
    const newX = x + offset.dx;
    const newY = y + offset.dy;

    if (
      newY >= 0 &&
      newY < maze.length &&
      newX >= 0 &&
      newX < maze[0].length &&
      maze[newY][newX].accessible
    ) {
      player.position = { x: newX, y: newY };
      player.orientation = newOrientation;
      const newPositionLabel = getPositionLabel(newX, newY);
      console.log(`Backend: Player turned ${move} and moved to position ${newPositionLabel} (${newX}, ${newY}), orientation: ${newOrientation}`);
      return { success: true };
    } else {
      return { success: false, message: `Impossible de tourner à ${move === 'left' ? 'gauche' : 'droite'}; chemin bloqué` };
    }
  } else {
    return { success: false, message: 'Mouvement invalide' };
  }
}



function getValidMoves(player, maze) {
  const { x, y } = player.position;
  const orientation = player.orientation;

  const orientations = ['north', 'east', 'south', 'west'];
  const idx = orientations.indexOf(orientation);

  const movementOffsets = {
    'north': { dx: 0, dy: -1 },
    'east': { dx: 1, dy: 0 },
    'south': { dx: 0, dy: 1 },
    'west': { dx: -1, dy: 0 },
  };

  // Fonction pour calculer les mouvements gauche et droite
  function getTurnMove(direction) {
    let newIdx = idx;
    if (direction === 'left') {
      newIdx = (idx + 3) % 4; // Tourner à gauche
    } else if (direction === 'right') {
      newIdx = (idx + 1) % 4; // Tourner à droite
    }
    const newOrientation = orientations[newIdx];
    const offset = movementOffsets[newOrientation];
    return { x: x + offset.dx, y: y + offset.dy };
  }

  // Calcul des positions potentielles
  const forward = {
    x: x + movementOffsets[orientation].dx,
    y: y + movementOffsets[orientation].dy,
  };
  const left = getTurnMove('left');
  const right = getTurnMove('right');

  // Vérification de l'accessibilité des positions
  const canMoveForward = isAccessible(forward, maze);
  const canMoveLeft = isAccessible(left, maze);
  const canMoveRight = isAccessible(right, maze);

  console.log(`Backend: Valid moves: { canMoveForward: ${canMoveForward}, canMoveLeft: ${canMoveLeft}, canMoveRight: ${canMoveRight} }`);

  return {
    canMoveForward,
    canMoveLeft,
    canMoveRight,
  };
}

function isAccessible(position, maze) {
  const { x, y } = position;
  if (
    y >= 0 &&
    y < maze.length &&
    x >= 0 &&
    x < maze[0].length
  ) {
    const accessible = maze[y][x].accessible;
    console.log(`Backend: Position x=${x}, y=${y} is ${accessible ? 'accessible' : 'blocked'}`);
    return accessible;
  }
  console.log(`Backend: Position x=${x}, y=${y} is out of bounds`);
  return false;
}



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

    try {
      // Récupérer une carte aléatoire
      const card = await getRandomCard();

      // Récupérer le nom du joueur actif avant de changer le joueur actif
      const gameData = await redisClient.hGetAll(`game:${gameId}`);
      const players = JSON.parse(gameData.players || '[]');
      const activePlayerId = gameData.activePlayerId;
      const activePlayer = players.find((p) => p.playerId === activePlayerId);
      const activePlayerName = activePlayer ? activePlayer.playerName : 'Joueur inconnu';

      // Remplacer le placeholder dans la description passive
      const cardDescriptionPassive = card.card_description_passif.replace('{activePlayerName}', activePlayerName);

      // Diffuser les descriptions à tous les clients
      io.to(gameId).emit('cardDrawn', {
        activePlayerName: activePlayerName,
        cardDescription: card.card_description,
        cardDescriptionPassive: cardDescriptionPassive,
        cardImage: card.card_image, // Envoi du nom de l'image de la carte
      });

      // Changer le joueur actif
      await changeActivePlayer(gameId, io);
    } catch (error) {
      console.error('Backend: Erreur lors de endTurn:', error);
      // Gérer l'erreur de manière appropriée
    }
  });

  socket.on('startGame', async ({ gameId }) => {
    console.log(`Backend: Demande de démarrage du jeu pour la partie ${gameId}`);
    try {
      const gameData = await redisClient.hGetAll(`game:${gameId}`);
      const maze = JSON.parse(gameData.maze || '[]');
      const players = JSON.parse(gameData.players || '[]');
  
      if (players.length === 0) {
        console.error(`Backend: Aucun joueur trouvé pour le jeu ${gameId}`);
        return;
      }
  
      const firstPlayer = players[0];
      const activePlayerName = firstPlayer.playerName;
  
      await redisClient.hSet(
        `game:${gameId}`,
        'activePlayerId',
        firstPlayer.playerId
      );
  
      // Draw a random card
      const card = await getRandomCard();
  
      // Prepare card descriptions
      const cardDescriptionPassive = card.card_description_passif.replace(
        '{activePlayerName}',
        activePlayerName
      );
  
      // Emit the startGame event with the necessary data
      io.to(gameId).emit('startGame', {
        maze: maze,
        players: players,
        activePlayerName: activePlayerName,
        cardDescription: card.card_description,
        cardDescriptionPassive: cardDescriptionPassive,
        cardImage: card.card_image,
        cardName: card.card_name,
      });
  
      console.log(
        `Backend: Premier joueur actif défini : ${activePlayerName} (ID: ${firstPlayer.playerId})`
      );
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

  socket.on('playerMove', async ({ gameId, playerId, move }) => {
    console.log(`Backend: Player ${playerId} is attempting to move ${move} in game ${gameId}`);
    
    try {
      const gameData = await redisClient.hGetAll(`game:${gameId}`);
      const players = JSON.parse(gameData.players || '[]');
      const player = players.find((p) => p.playerId === playerId);
  
      if (!player) {
        console.error(`Backend: Player with ID ${playerId} not found in game ${gameId}.`);
        socket.emit('moveError', { message: 'Player not found' });
        return;
      }
  
      // Load the maze directly from the module
      const maze = require('../models/map');
  
      const validMoves = getValidMoves(player, maze);
      console.log(`Backend: Valid moves for player ${playerId}:`, validMoves);
  
      // Check if the move is valid before proceeding
      if (
        (move === 'forward' && !validMoves.canMoveForward) ||
        (move === 'left' && !validMoves.canMoveLeft) ||
        (move === 'right' && !validMoves.canMoveRight)
      ) {
        socket.emit('moveError', { message: 'Invalid move' });
        return;
      }
  
      // Process the player's move
      const result = processPlayerMove(player, move, maze);
  
      if (result.success) {
        // Update the players data in Redis
        await redisClient.hSet(`game:${gameId}`, 'players', JSON.stringify(players));
  
        // Emit position update to all clients in the game
        io.to(gameId).emit('positionUpdate', {
          playerId,
          position: player.position,
          orientation: player.orientation,
        });
      } else {
        socket.emit('moveError', { message: result.message });
      }
    } catch (error) {
      console.error('Backend: Error processing player move:', error);
      socket.emit('moveError', { message: 'Error processing move' });
    }
  });
  
  socket.on('getValidMoves', async ({ gameId, playerId }) => {
    try {
      const gameData = await redisClient.hGetAll(`game:${gameId}`);
      const players = JSON.parse(gameData.players || '[]');
      const player = players.find((p) => p.playerId === playerId);
  
      if (!player) {
        socket.emit('validMoves', { error: 'Player not found' });
        return;
      }
  
      // Load the maze directly from the module
      const maze = require('../models/map');
  
      const validMoves = getValidMoves(player, maze);
  
      console.log(`Backend: Valid moves for player ${playerId}:`, validMoves);
  
      socket.emit('validMoves', validMoves);
    } catch (error) {
      console.error('Backend: Error getting valid moves:', error);
      socket.emit('validMoves', { error: 'Error getting valid moves' });
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
