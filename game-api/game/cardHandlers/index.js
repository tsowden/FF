// cardHandlers/index.js

const ChallengeCardHandler = require('./challengeCardHandler');
const GenericCardHandler = require('./genericCardHandler');

function getCardHandlerForCategory(gameId, io, cardCategory) {
  switch (cardCategory) {
    case 'Challenge':
      return new ChallengeCardHandler(gameId, io);
    // case 'Treasure':
    //   return new TreasureCardHandler(gameId, io);
    // case 'Trap':
    //   return new TrapCardHandler(gameId, io);
    default:
      // Si on n'a pas de type spécifique, on retourne le handler générique
      return new GenericCardHandler(gameId, io);
  }
}

module.exports = { getCardHandlerForCategory };
