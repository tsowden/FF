// models/card.js
const db = require('../config/db'); 


async function getRandomCard() {
  try {
    const [rows] = await db.query('SELECT * FROM cards ORDER BY RAND() LIMIT 1');

    if (!rows || rows.length === 0) {
      return null;
    }
    return rows[0];
  } catch (error) {
    console.error('Erreur lors de la récupération de la carte:', error);
    throw error; 
  }
}

module.exports = getRandomCard;
