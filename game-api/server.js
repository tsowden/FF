require('dotenv').config();
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const redis = require('redis'); // Importation du client Redis

const app = express();
const port = process.env.PORT || 3000;

// Initialisation de Redis
const redisClient = redis.createClient({
  url: 'redis://localhost:6379' // Changez l'URL si votre configuration Redis est différente
});

// Connectez-vous à Redis
redisClient.connect().catch(console.error);

// Créez le serveur HTTP
const server = http.createServer(app);

// Configurez Socket.IO avec le serveur HTTP
const io = new Server(server, {
  cors: {
    origin: '*', // Changez cette valeur pour autoriser les domaines spécifiques
    methods: ['GET', 'POST']
  }
});

app.use(express.json());

app.get('/', (req, res) => {
  res.send('API de jeu en Node.js est en ligne');
});

const gameRoutes = require('./routes/gameRoutes')(io, redisClient);
const questionRoutes = require('./routes/questionRoutes');

app.use('/api/game', gameRoutes);
app.use('/api/question', questionRoutes);

io.on('connection', (socket) => {
  console.log('Un joueur s\'est connecté');

  socket.on('joinRoom', async (gameId) => {
    socket.join(gameId);

    try {
      const players = JSON.parse(await redisClient.hGet(`game:${gameId}`, 'players')) || [];
      io.to(gameId).emit('currentPlayers', players);
    } catch (error) {
      console.error('Erreur lors de la récupération des joueurs:', error);
    }
  });

  socket.on('disconnect', () => {
    console.log('Un joueur s\'est déconnecté');
  });
});

// Démarrer le serveur
server.listen(port, () => {
  console.log(`Serveur démarré sur le port ${port}`);
});
