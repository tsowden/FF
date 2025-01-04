// models/card.js
const db = require('../config/db'); // Assure-toi que ce 'db' est un pool mysql2/promise

/**
 * getRandomCard() :
 *   Récupère une carte aléatoire depuis la table "cards".
 */
async function getRandomCard() {
  try {
    // Ici, db.query renvoie [rows, fields] grâce à mysql2/promise
    const [rows] = await db.query('SELECT * FROM cards ORDER BY RAND() LIMIT 1');

    if (!rows || rows.length === 0) {
      // Aucune carte trouvée
      return null;
    }
    // On renvoie la première carte
    return rows[0];
  } catch (error) {
    console.error('Erreur lors de la récupération de la carte:', error);
    throw error; // On laisse l'erreur remonter
  }
}

module.exports = getRandomCard;
