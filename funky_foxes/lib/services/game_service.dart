import 'package:socket_io_client/socket_io_client.dart' as IO;

class GameService {
  late IO.Socket socket;

  void connectToGame(String gameId) {
    // Configurez la connexion WebSocket
    socket = IO.io('http://192.168.0.53:3000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    // Écoutez les événements de connexion et de déconnexion
    socket.onConnect((_) {
      print('Connecté au serveur');
      joinRoom(gameId);
    });

    socket.onDisconnect((_) {
      print('Déconnecté du serveur');
    });

    socket.on('currentPlayers', (data) {
      print("Données reçues dans 'currentPlayers': $data");
    });

    socket.on('playerJoined', (data) {
      print("Nouveau joueur rejoint : ${data['playerName']}");
    });

    // Connexion au serveur
    socket.connect();
  }

  void joinRoom(String gameId) {
    // Rejoindre la salle de jeu via un événement spécifique
    print("Rejoindre la salle avec gameId : $gameId");
    socket.emit('joinRoom', gameId);
  }

  void disconnect() {
    socket.disconnect();
  }
}
