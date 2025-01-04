require('dotenv').config();
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');

// Importation des modules nécessaires
const redisClient = require('./config/redis');
const handleSocketEvents = require('./sockets/socketHandlers');
const gameRoutes = require('./routes/gameRoutes');
const questionRoutes = require('./routes/questionRoutes');

const app = express();
const port = process.env.PORT || 3000;

// Middleware pour parser le JSON et gérer les CORS
app.use(express.json());
app.use(cors());

// Crée le serveur HTTP
const server = http.createServer(app);

// Configure Socket.IO
const io = new Server(server, {
  cors: {
    origin: '*', // Autorise toutes les origines
    methods: ['GET', 'POST'],
  },
});

// Middleware pour attacher io à req (pour les routes HTTP qui en ont besoin)
app.use((req, res, next) => {
  req.io = io;
  next();
});

// Logger les requêtes HTTP
app.use((req, res, next) => {
  console.log(`Requête ${req.method} reçue sur ${req.url}`);
  next();
});

// Routes HTTP
app.use('/api/game', gameRoutes);
app.use('/api/question', questionRoutes);

// Gestion des connexions Socket.IO
io.on('connection', (socket) => {
  console.log('Backend: Un joueur s\'est connecté');
  handleSocketEvents(io, socket);

  socket.on('disconnect', () => {
    console.log('Backend: Un joueur s\'est déconnecté');
  });
});

// Démarre le serveur
server.listen(port, '0.0.0.0', () => {
  console.log(`Backend: Serveur accessible sur toutes les interfaces, port ${port}`);
});

