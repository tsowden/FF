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
    socket.on('connect', (_) {
      print('GameService: Connecté au serveur Socket.IO');
      joinRoom(gameId);
    });

    socket.on('disconnect', (_) {
      print('GameService: Déconnecté du serveur Socket.IO');
    });

    socket.connect();
  }

  void joinRoom(String gameId) {
    print("GameService: Rejoindre la salle avec gameId : $gameId via Socket.IO");
    socket.emit('joinRoom', gameId);
  }

  void setReadyStatus(String gameId, String playerName, bool isReady) {
    print("GameService: Mise à jour de l'état prêt pour $playerName dans la salle $gameId : $isReady");
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

  void onActivePlayerChanged(Function(Map<String, dynamic>) callback) {
    socket.on('activePlayerChanged', (data) {
      print("GameService: Joueur actif changé avec les données : $data");
      callback(Map<String, dynamic>.from(data));
    });
  }

  void onStartGame(Function(Map<String, dynamic>) callback) {
    socket.on('startGame', (data) {
      print("GameService: Jeu démarré avec les données : $data");
      callback(Map<String, dynamic>.from(data));
    });
  }


  void getActivePlayer(String gameId) {
    print("GameService: Demande du joueur actif pour la partie $gameId au serveur...");
    socket.emit('getActivePlayer', gameId);
  }

  void onActivePlayerReceived(Function(String) callback) {
    socket.on('activePlayer', (data) {
      print("GameService: Reçu activePlayer : ${data['activePlayerName']}");
      callback(data['activePlayerName']);
    });
  }


  void disconnect() {
    print("GameService: Déconnexion du serveur Socket.IO");
    socket.disconnect();
  }
}
