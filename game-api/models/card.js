// models/card.js

const db = require('../config/db');

// Function to get a random card
function getRandomCard() {
  return new Promise((resolve, reject) => {
    db.query('SELECT * FROM cards ORDER BY RAND() LIMIT 1', (error, results) => {
      if (error) {
        console.error('Erreur lors de la récupération de la carte:', error);
        reject(error);
      } else {
        resolve(results[0]); // Return the first (and only) card
      }
    });
  });
}

module.exports = getRandomCard;
