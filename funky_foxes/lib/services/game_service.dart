import 'dart:async';
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

  void onCurrentPlayers(Function(List<dynamic>) callback) {
    socket.on('currentPlayers', (data) {
      print("GameService: Current players received: $data");
      callback(List<dynamic>.from(data));
    });
  }

  void endTurn(String gameId) {
    print("GameService: Fin du tour pour la salle $gameId");
    socket.emit('endTurn', gameId);
  }

  void onActivePlayerChanged(Function(Map<String, dynamic>) callback) {
    socket.on('activePlayerChanged', (data) {
      _logPlayerPosition(data);
      callback(Map<String, dynamic>.from(data));
    });
  }

  void onStartGame(Function(Map<String, dynamic>) callback) {
    socket.on('startGame', (data) {
      _logPlayerPosition(data);
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
      _logPlayerPosition(data);
      callback(data['activePlayerName']);
    });
  }

  void movePlayer(String gameId, String playerId, String move) {
    print("GameService: Player $playerId moving $move in game $gameId");
    socket.emit('playerMove', {
      'gameId': gameId,
      'playerId': playerId,
      'move': move,
    });
  }

  void onPositionUpdate(Function(Map<String, dynamic>) callback) {
    socket.on('positionUpdate', (data) {
      print("GameService: Received position update: $data");
      _logPlayerPosition(data);
      callback(Map<String, dynamic>.from(data));
    });
  }


  void onValidMovesReceived(Function(Map<String, bool>) callback) {
    socket.on('validMoves', (data) {
      print("GameService: Valid moves received: $data");
      callback({
        'canMoveForward': data['canMoveForward'] ?? false,
        'canMoveLeft': data['canMoveLeft'] ?? false,
        'canMoveRight': data['canMoveRight'] ?? false,
      });
    });
  }
  
  // In game_service.dart
  void getValidMoves(String gameId, String playerId, Function(Map<String, bool>) callback) {
    print("GameService: Requesting valid moves for player $playerId in game $gameId");
    socket.emit('getValidMoves', {'gameId': gameId, 'playerId': playerId});
    socket.once('validMoves', (data) {
      if (data != null && data is Map) {
        print("GameService: Received valid moves: $data");
        callback(Map<String, bool>.from(data));
      } else {
        print("GameService: Error getting valid moves");
        callback({'canMoveForward': false, 'canMoveLeft': false, 'canMoveRight': false});
      }
    });
  }


  void onMoveError(Function(String) callback) {
    socket.on('moveError', (data) {
      print("GameService: Move error received: $data");
      callback(data['message']);
    });
  }

  void onCardDrawn(Function(Map<String, dynamic>) callback) {
    socket.on('cardDrawn', (data) {
      print("GameService: Card drawn event received: $data");
      callback(Map<String, dynamic>.from(data));
    });
  }

  Future<String?> getPlayerId(String gameId, String playerName) async {
    final Completer<String?> completer = Completer();

    socket.emit('getPlayerId', {'gameId': gameId, 'playerName': playerName});

    socket.once('playerId', (data) {
      if (data != null && data['playerId'] != null) {
        completer.complete(data['playerId']);
      } else {
        completer.completeError('Player ID introuvable.');
      }
    });

    return completer.future;
  }

  void disconnect() {
    print("GameService: Déconnexion du serveur Socket.IO");
    socket.disconnect();
  }

  /// Helper pour loguer la position alphanumérique
  void _logPlayerPosition(Map<String, dynamic> data) {
    if (data.containsKey('position') && data['position'] is Map) {
      final position = data['position'];
      final x = position['x'] ?? 0;
      final y = position['y'] ?? 0;
      final alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
      final formattedPosition = "${alphabet[x]}${y + 1}";
      print("GameService: Position actuelle du joueur : $formattedPosition");
    }
  }
}
