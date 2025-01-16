  // game/turnManager.js
  const redisClient = require('../config/redis');
  const getRandomCard = require('../models/card');
  const { getCardHandlerForCategory } = require('./cardHandlers');

  class TurnManager {
    constructor(gameId, io) {
      this.gameId = gameId;
      this.io = io;
    }

    async handleMove(playerId, move) {
      const gameData = await redisClient.hGetAll(`game:${this.gameId}`);
      const players = JSON.parse(gameData.players || '[]');
      const player = players.find((p) => p.playerId === playerId);

      if (!player) {
        console.error(`TurnManager: Player with ID ${playerId} not found in game ${this.gameId}.`);
        this.io.to(this.gameId).emit('moveError', { message: 'Player not found' });
        return;
      }

      const maze = require('../models/map');
      const validMoves = this.getValidMoves(player, maze);

      if (
        (move === 'forward' && !validMoves.canMoveForward) ||
        (move === 'left' && !validMoves.canMoveLeft) ||
        (move === 'right' && !validMoves.canMoveRight)
      ) {
        this.io.to(this.gameId).emit('moveError', { message: 'Invalid move' });
        return;
      }

      const result = this.processPlayerMove(player, move, maze);

      if (result.success) {
        await redisClient.hSet(`game:${this.gameId}`, 'players', JSON.stringify(players));

        this.io.to(this.gameId).emit('positionUpdate', {
          playerId,
          position: player.position,
          orientation: player.orientation,
        });

        await this.drawCard(player);
      } else {
        this.io.to(this.gameId).emit('moveError', { message: result.message });
      }
    }

    getValidMoves(player, maze) {
      const { x, y } = player.position;
      const orientation = player.orientation;

      const orientations = ['north', 'east', 'south', 'west'];
      const idx = orientations.indexOf(orientation);

      const movementOffsets = {
        north: { dx: 0, dy: -1 },
        east: { dx: 1, dy: 0 },
        south: { dx: 0, dy: 1 },
        west: { dx: -1, dy: 0 },
      };

      const isAccessible = (pos) =>
        pos.y >= 0 &&
        pos.y < maze.length &&
        pos.x >= 0 &&
        pos.x < maze[0].length &&
        maze[pos.y][pos.x].accessible;

      const forward = {
        x: x + movementOffsets[orientation].dx,
        y: y + movementOffsets[orientation].dy,
      };

      const getTurnMove = (direction) => {
        let newIdx = idx;
        if (direction === 'left') newIdx = (idx + 3) % 4;
        if (direction === 'right') newIdx = (idx + 1) % 4;
        const newOrientation = orientations[newIdx];
        return {
          x: x + movementOffsets[newOrientation].dx,
          y: y + movementOffsets[newOrientation].dy,
        };
      };

      const left = getTurnMove('left');
      const right = getTurnMove('right');

      return {
        canMoveForward: isAccessible(forward),
        canMoveLeft: isAccessible(left),
        canMoveRight: isAccessible(right),
      };
    }

    processPlayerMove(player, move, maze) {
      let { x, y } = player.position;
      let orientation = player.orientation;

      const orientations = ['north', 'east', 'south', 'west'];
      const idx = orientations.indexOf(orientation);

      const movementOffsets = {
        north: { dx: 0, dy: -1 },
        east: { dx: 1, dy: 0 },
        south: { dx: 0, dy: 1 },
        west: { dx: -1, dy: 0 },
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
          return { success: true };
        } else {
          return { success: false, message: 'Impossible d\'avancer; chemin bloqué' };
        }
      } else if (move === 'left' || move === 'right') {
        let newIdx = idx;
        if (move === 'left') newIdx = (idx + 3) % 4;
        if (move === 'right') newIdx = (idx + 1) % 4;
        player.orientation = orientations[newIdx];
        return { success: true };
      } else {
        return { success: false, message: 'Mouvement invalide' };
      }
    }

    async drawCard(player) {
      const card = await getRandomCard();
      await redisClient.hSet(`game:${this.gameId}`, 'currentCard', JSON.stringify(card));

      const { getCardHandlerForCategory } = require('./cardHandlers');
      const handler = getCardHandlerForCategory(this.gameId, this.io, card.card_category);

      await handler.handleCard(player.playerId, card);
    }

    async changeActivePlayer() {
      const gameData = await redisClient.hGetAll(`game:${this.gameId}`);
      if (!gameData) {
        console.error(`TurnManager: Aucune donnée de jeu trouvée pour ${this.gameId}`);
        return;
      }

      const players = JSON.parse(gameData.players || '[]');
      let currentIndex = players.findIndex((p) => p.playerId === gameData.activePlayerId);

      if (currentIndex === -1) {
        console.error(`TurnManager: Joueur actif introuvable dans ${this.gameId}`);
        return;
      }

      currentIndex = (currentIndex + 1) % players.length;
      const newActivePlayer = players[currentIndex];

      await redisClient.hSet(`game:${this.gameId}`, 'activePlayerId', newActivePlayer.playerId);

      console.log(`TurnManager: Nouveau joueur actif: ${newActivePlayer.playerName} (ID: ${newActivePlayer.playerId})`);
      this.io.to(this.gameId).emit('activePlayerChanged', {
        activePlayerId: newActivePlayer.playerId,
        activePlayerName: newActivePlayer.playerName,
        turnState: 'movement',
      });
    }
  }

  module.exports = TurnManager;
