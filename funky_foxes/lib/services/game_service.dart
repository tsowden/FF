import 'package:socket_io_client/socket_io_client.dart' as IO;

class GameService {
  late IO.Socket socket;

  GameService() {
    // Initialise le socket dans le constructeur
    socket = IO.io(
      'http://192.168.0.53:3000',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );
  }

  void connectToGame(String gameId) {
    print('GameService: Tentative de connexion au jeu $gameId');

    // Configure les écouteurs d'événements de connexion
    socket.on('connect', (_) {
      print('GameService: Connecté au serveur Socket.IO');
      joinRoom(gameId);
    });

    socket.on('disconnect', (_) {
      print('GameService: Déconnecté du serveur Socket.IO');
    });

    // Lance manuellement la connexion
    socket.connect();
  }

  void joinRoom(String gameId) {
    print("GameService: Rejoindre la salle avec gameId : $gameId via Socket.IO");
    socket.emit('joinRoom', gameId);
  }

  void setReadyStatus(String gameId, String playerName, bool isReady) {
    print(
        "GameService: Mise à jour de l'état prêt pour $playerName dans la salle $gameId : $isReady");
    socket.emit('playerReady', {
      'gameId': gameId,
      'playerName': playerName,
      'isReady': isReady,
    });
  }

  void startGame(String gameId) {
    print("GameService: Demande de démarrage du jeu pour la salle $gameId");
    socket.emit('startGame', {'gameId': gameId});
  }

  void endTurn(String gameId) {
    print("GameService: Fin du tour pour la salle $gameId");
    socket.emit('endTurn', gameId);
  }

  // Écoute les changements de joueur actif
  void onActivePlayerChanged(Function(String activePlayerName) callback) {
    socket.on('activePlayerChanged', (data) {
      final activePlayerName = data['activePlayerName'];
      print("GameService: Changement de joueur actif reçu : $activePlayerName");
      callback(activePlayerName);
    });
  }

  // Écoute le démarrage du jeu
  void onStartGame(Function(String activePlayerName) callback) {
    socket.on('startGame', (data) {
      final activePlayerName = data['activePlayerName'];
      print("GameService: Événement startGame reçu avec le joueur actif : $activePlayerName");
      callback(activePlayerName);
    });
  }

  // Méthode pour demander le joueur actif
  void getActivePlayer(String gameId) {
    print("GameService: Demande du joueur actif pour la partie $gameId au serveur...");
    socket.emit('getActivePlayer', gameId);
  }

  // Écoute la réponse du joueur actif
  void onActivePlayerReceived(Function(String activePlayerName) callback) {
    socket.on('activePlayer', (data) {
      final activePlayerName = data['activePlayerName'];
      print("GameService: Reçu activePlayer : $activePlayerName");
      callback(activePlayerName);
    });
  }

  // Méthode pour écouter les mises à jour des joueurs
  void onCurrentPlayersUpdate(Function(List<Map<String, dynamic>>) callback) {
    socket.on('currentPlayers', (data) {
      final List<Map<String, dynamic>> players =
          List<Map<String, dynamic>>.from(data);
      print("GameService: Mise à jour des joueurs : $players");
      callback(players);
    });
  }

  // Écoute l'événement allPlayersReady
  void onAllPlayersReady(Function callback) {
    socket.on('allPlayersReady', (_) {
      print("GameService: Tous les joueurs sont prêts");
      callback();
    });
  }

  // Écoute les mises à jour du statut prêt des joueurs
  void onReadyStatusUpdate(Function(String playerName, bool isReady) callback) {
    socket.on('readyStatusUpdate', (data) {
      final playerName = data['playerName'];
      final isReady = data['isReady'];
      print("GameService: Statut prêt mis à jour pour $playerName : $isReady");
      callback(playerName, isReady);
    });
  }

  void disconnect() {
    print("GameService: Déconnexion du serveur Socket.IO");
    socket.disconnect();
  }
}
