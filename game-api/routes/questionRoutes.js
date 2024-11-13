const express = require('express');
const router = express.Router();
const db = require('../config/db');

// Route pour récupérer toutes les cartes
router.get('/cards', (req, res) => {
  db.query('SELECT * FROM Cards', (err, results) => {
    if (err) {
      res.status(500).json({ error: 'Erreur lors de la récupération des cartes' });
    } else {
      res.json(results);
    }
  });
});

// Route pour récupérer toutes les questions
router.get('/questions', (req, res) => {
  db.query('SELECT * FROM Questions', (err, results) => {
    if (err) {
      res.status(500).json({ error: 'Erreur lors de la récupération des questions' });
    } else {
      res.json(results);
    }
  });
});

module.exports = router;
