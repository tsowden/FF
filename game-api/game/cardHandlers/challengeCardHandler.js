// game/cardHandlers/challengeCardHandler.js
const redisClient = require('../../config/redis');
const GenericCardHandler = require('./genericCardHandler');

class ChallengeCardHandler extends GenericCardHandler {
  constructor(gameId, io) {
    super(gameId, io);
  }

  async handleCard(playerId, card) {
    await super.handleCard(playerId, card);
    console.log(`ChallengeCardHandler: Challenge card drawn. Waiting for 'startBetting'...`);
  }

  async startBetting() {
    try {
      await redisClient.hSet(`game:${this.gameId}`, 'turnState', 'betting');
      await redisClient.hSet(`game:${this.gameId}`, 'bets', JSON.stringify({}));

      this.io.to(this.gameId).emit('turnStateChanged', { turnState: 'betting' });
      console.log(`ChallengeCardHandler: Betting phase started for game ${this.gameId}.`);
    } catch (error) {
      console.error('ChallengeCardHandler: Error starting betting phase:', error);
    }
  }

  async handleBet(playerId, bet) {
    try {
      const gameData = await redisClient.hGetAll(`game:${this.gameId}`);
      const currentCard = JSON.parse(gameData.currentCard || '{}');
      const bets = JSON.parse(gameData.bets || '{}');

      const validBets = currentCard.validBets || [];
      if (!validBets.includes(bet)) {
        console.error(`ChallengeCardHandler: Invalid bet "${bet}" from player ${playerId}`);
        return { error: 'Invalid bet' };
      }

      bets[playerId] = bet;
      await redisClient.hSet(`game:${this.gameId}`, 'bets', JSON.stringify(bets));
      console.log(`ChallengeCardHandler: Bet "${bet}" recorded for player ${playerId}.`);

      // Vérifier si tous les joueurs non actifs ont parié
      const players = JSON.parse(gameData.players || '[]');
      const nonActivePlayers = players.filter((p) => p.playerId !== gameData.activePlayerId);
      if (Object.keys(bets).length >= nonActivePlayers.length) {
        console.log(`ChallengeCardHandler: All bets received`);
        await this.startChallenge();
      }
    } catch (error) {
      console.error(`ChallengeCardHandler: Error handling bet:`, error);
    }
  }

  async startChallenge() {
    try {
      await redisClient.hSet(`game:${this.gameId}`, 'turnState', 'challengeInProgress');
      this.io.to(this.gameId).emit('turnStateChanged', { turnState: 'challengeInProgress' });
      console.log(`ChallengeCardHandler: Challenge started for game ${this.gameId}.`);
    } catch (error) {
      console.error(`ChallengeCardHandler: Error starting challenge:`, error);
    }
  }

  async processChallengeResult(playerId, result) {
    try {
      await redisClient.hSet(`game:${this.gameId}`, 'turnState', 'result');

      const gameData = await redisClient.hGetAll(`game:${this.gameId}`);
      const bets = JSON.parse(gameData.bets || '{}');
      const players = JSON.parse(gameData.players || '[]');
      const activePlayer = players.find((p) => p.playerId === playerId);

      if (!activePlayer) {
        console.error(`ChallengeCardHandler: Player with ID ${playerId} not found for result processing.`);
        return;
      }

      console.log(`ChallengeCardHandler: Processing result for player ${activePlayer.playerName}. Result: ${result}`);

      // MàJ scores
      for (const [bettingPlayerId, bet] of Object.entries(bets)) {
        const bettingPlayer = players.find((p) => p.playerId === bettingPlayerId);
        if (bettingPlayer && bet === result) {
          bettingPlayer.score = (bettingPlayer.score || 0) + 1;
        }
      }
      if (result === 'success') {
        activePlayer.score = (activePlayer.score || 0) + 2;
      }

      await redisClient.hSet(`game:${this.gameId}`, 'players', JSON.stringify(players));

      // Notifier
      this.io.to(this.gameId).emit('challengeResult', {
        activePlayerName: activePlayer.playerName,
        result,
        rewards: players.map((p) => ({
          playerName: p.playerName,
          score: p.score || 0,
        })),
      });

      console.log(`ChallengeCardHandler: Challenge result broadcasted (game ${this.gameId}).`);
    } catch (error) {
      console.error(`ChallengeCardHandler: Error processing challenge result:`, error);
    }
  }

  async handleChallengeVote(playerId, vote) {
    try {
      const gameData = await redisClient.hGetAll(`game:${this.gameId}`);
      const votes = JSON.parse(gameData.votes || '{}');
      votes[playerId] = vote;
      await redisClient.hSet(`game:${this.gameId}`, 'votes', JSON.stringify(votes));

      const players = JSON.parse(gameData.players || '[]');
      const nonActivePlayers = players.filter((p) => p.playerId !== gameData.activePlayerId);

      // Vérifier la majorité
      if (Object.keys(votes).length >= Math.ceil(nonActivePlayers.length / 2)) {
        const voteCounts = {};
        Object.values(votes).forEach((v) => {
          voteCounts[v] = (voteCounts[v] || 0) + 1;
        });

        const maxVotes = Math.max(...Object.values(voteCounts));
        const majorityVotes = Object.keys(voteCounts).filter(
          (option) => voteCounts[option] === maxVotes
        );

        if (majorityVotes.length === 1) {
          const majorityVote = majorityVotes[0];
          await redisClient.hSet(`game:${this.gameId}`, 'turnState', 'result');
          await redisClient.hSet(`game:${this.gameId}`, 'majorityVote', majorityVote);

          this.io.to(this.gameId).emit('turnStateChanged', {
            turnState: 'result',
            majorityVote,
          });
          console.log(`ChallengeCardHandler: Majority vote reached: ${majorityVote}`);
        } else {
          // Égalité ou reste des joueurs
          const remainingPlayers = nonActivePlayers.filter((p) => !votes.hasOwnProperty(p.playerId));
          if (remainingPlayers.length > 0) {
            this.io.to(this.gameId).emit('challengeVotesUpdated', {
              isMajorityReached: false,
            });
          } else {
            // Égalité => vote aléatoire
            const majorityVote = majorityVotes[Math.floor(Math.random() * majorityVotes.length)];
            await redisClient.hSet(`game:${this.gameId}`, 'turnState', 'result');
            await redisClient.hSet(`game:${this.gameId}`, 'majorityVote', majorityVote);

            this.io.to(this.gameId).emit('turnStateChanged', {
              turnState: 'result',
              majorityVote,
            });
            console.log(`ChallengeCardHandler: Tie => random majority vote: ${majorityVote}`);
          }
        }
      } else {
        this.io.to(this.gameId).emit('challengeVotesUpdated', { isMajorityReached: false });
      }
    } catch (error) {
      console.error(`ChallengeCardHandler: Error processing challenge vote:`, error);
    }
  }

  async transitionToNextTurn() {
    try {
      const gameData = await redisClient.hGetAll(`game:${this.gameId}`);
      const players = JSON.parse(gameData.players || '[]');
      let currentIndex = players.findIndex((p) => p.playerId === gameData.activePlayerId);

      if (currentIndex === -1) {
        console.error(`ChallengeCardHandler: Active player not found in game ${this.gameId}.`);
        return;
      }

      currentIndex = (currentIndex + 1) % players.length;
      const nextPlayer = players[currentIndex];

      await redisClient.hSet(`game:${this.gameId}`, 'activePlayerId', nextPlayer.playerId);

      this.io.to(this.gameId).emit('activePlayerChanged', {
        activePlayerId: nextPlayer.playerId,
        activePlayerName: nextPlayer.playerName,
        turnState: 'movement',
      });
      console.log(`ChallengeCardHandler: Turn ended. Next player: ${nextPlayer.playerName} (game ${this.gameId})`);
    } catch (error) {
      console.error(`ChallengeCardHandler: Error transitioning to next turn:`, error);
    }
  }
}

module.exports = ChallengeCardHandler;
