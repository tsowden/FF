require('dotenv').config();
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const redisClient = require('./config/redis');
const cors = require('cors');

const app = express();
const port = process.env.PORT || 3000;

// Middleware pour parser le JSON
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

// Middleware pour attacher io à req
app.use((req, res, next) => {
  req.io = io;
  next();
});

// Logger les requêtes
app.use((req, res, next) => {
  console.log(`Requête ${req.method} reçue sur ${req.url}`);
  next();
});

// Importation des routes
const gameRoutes = require('./routes/gameRoutes');
const questionRoutes = require('./routes/questionRoutes');
const { handleSocketEvents } = require('./controllers/gameController');

// Utilisation des routes
app.use('/api/game', gameRoutes);
app.use('/api/question', questionRoutes); // Si vous avez des routes pour les questions

// Gestion des connexions Socket.IO globales
io.on('connection', (socket) => {
  console.log('Un joueur s\'est connecté');

  // Appel de handleSocketEvents
  handleSocketEvents(io, socket);

  socket.on('disconnect', () => {
    console.log('Un joueur s\'est déconnecté');
  });
});

// Démarre le serveur
server.listen(port, () => {
  console.log(`Serveur démarré sur le port ${port}`);
});
