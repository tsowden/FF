// lib/services/game_service.dart

import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class GameService {
  late IO.Socket socket;

  String? majorityVote;

  GameService() {
    // Initialize the socket in the constructor
    socket = IO.io(
      'http://192.168.0.53:3000',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );
  }

  void connectToGame(String gameId) {
    print('GameService: Connecting to game $gameId');
    socket.on('connect', (_) {
      print('GameService: Connected to Socket.IO server');
      joinRoom(gameId);
    });

    socket.on('disconnect', (_) {
      print('GameService: Disconnected from Socket.IO server');
    });

    socket.connect();
  }

  void joinRoom(String gameId) {
    print("GameService: Joining room with gameId: $gameId via Socket.IO");
    socket.emit('joinRoom', gameId);
  }

  void setReadyStatus(String gameId, String playerName, bool isReady) {
    print(
        "GameService: Updating ready status for $playerName in room $gameId: $isReady");
    socket.emit('playerReady', {
      'gameId': gameId,
      'playerName': playerName,
      'isReady': isReady,
    });
  }

  void startGame(String gameId) {
    print("GameService: Requesting to start game for room $gameId");
    socket.emit('startGame', {'gameId': gameId});
  }

  void onCurrentPlayers(Function(List<dynamic>) callback) {
    socket.on('currentPlayers', (data) {
      print("GameService: Current players received: $data");
      callback(List<dynamic>.from(data));
    });
  }

  void endTurn(String gameId) {
    print("GameService: Ending turn for game $gameId");
    socket.emit('endTurn', gameId); 
  }


  void onTurnStarted(Function(Map<String, dynamic>) callback) {
    socket.on('turnStarted', (data) {
      print("GameService: Turn started event received: $data");
      callback(Map<String, dynamic>.from(data));
    });
  }

  // Méthode pour écouter les changements de turnState
  void onTurnStateChanged(Function(Map<String, dynamic>) callback) {
    socket.on('turnStateChanged', (data) {
      print("GameService: Turn state changed: $data");
      callback(Map<String, dynamic>.from(data));
    });
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
    print("GameService: Requesting active player for game $gameId...");
    socket.emit('getActivePlayer', {'gameId': gameId});
  }

  void onActivePlayerReceived(Function(String) callback) {
    socket.on('activePlayer', (data) {
      print("GameService: Received activePlayer: ${data['activePlayerName']}");
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

  void getValidMoves(
      String gameId, String playerId, Function(Map<String, bool>) callback) {
    print(
        "GameService: Requesting valid moves for player $playerId in game $gameId");
    socket.emit('getValidMoves', {'gameId': gameId, 'playerId': playerId});
    socket.once('validMoves', (data) {
      if (data != null && data is Map) {
        print("GameService: Received valid moves: $data");
        callback(Map<String, bool>.from(data));
      } else {
        print("GameService: Error getting valid moves");
        callback(
            {'canMoveForward': false, 'canMoveLeft': false, 'canMoveRight': false});
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

  // New method to handle betting ended
  void onBettingEnded(Function() callback) {
    socket.on('bettingEnded', (_) {
      print("GameService: Betting phase ended");
      callback();
    });
  }

  void onBetPlaced(Function(Map<String, dynamic>) callback) {
    socket.on('betPlaced', (data) {
      print("GameService: Bet placed event received: $data");
      callback(Map<String, dynamic>.from(data));
    });
  }


  // New method to handle challenge started
  void onChallengeStarted(Function() callback) {
    socket.on('challengeStarted', (_) {
      print("GameService: Challenge started");
      callback();
    });
  }

  // New method to handle challenge result
  void onChallengeResult(Function(Map<String, dynamic>) callback) {
    socket.on('challengeResult', (data) {
      print("GameService: Challenge result received: $data");
      callback(Map<String, dynamic>.from(data));
    });
  }

  // Méthode pour démarrer la phase de pari (joueur actif)
  void startBetting(String gameId, String playerId) {
    print("GameService: Player $playerId is starting betting in game $gameId");
    socket.emit('startBetting', {
      'gameId': gameId,
      'playerId': playerId,
    });
  }

  // Méthode pour placer un pari (joueurs non actifs)
  void placeBet(String gameId, String playerId, String bet) {
    print("GameService: Player $playerId placing bet $bet in game $gameId");
    socket.emit('placeBet', {
      'gameId': gameId,
      'playerId': playerId,
      'bet': bet,
    });
  }

  void placeChallengeVote(String gameId, String playerId, String vote) {
    print("GameService: Player $playerId voting $vote in challenge for game $gameId");
    socket.emit('placeChallengeVote', {
      'gameId': gameId,
      'playerId': playerId,
      'vote': vote,
    });
  }

  void onChallengeVotesUpdated(Function(Map<String, dynamic>) callback) {
    socket.on('challengeVotesUpdated', (data) {
      print("GameService: Challenge votes updated: $data");

      // Met à jour la propriété majorityVote
      if (data['isMajorityReached'] == true) {
        majorityVote = data['majorityVote'];
      }

      callback(data);
    });
  }

  // Method to start a challenge
  void startChallenge(String gameId, String playerId) {
    print("GameService: Player $playerId starting challenge in game $gameId");
    socket.emit('startChallenge', {
      'gameId': gameId,
      'playerId': playerId,
    });
  }

  // Method to send challenge result
  void sendChallengeResult(String gameId, String playerId, String result) {
    print(
        "GameService: Sending challenge result $result for player $playerId in game $gameId");
    socket.emit('challengeResult', {
      'gameId': gameId,
      'playerId': playerId,
      'result': result,
    });
  }

  Future<String?> getPlayerId(String gameId, String playerName) async {
    final Completer<String?> completer = Completer();

    socket.emit('getPlayerId', {'gameId': gameId, 'playerName': playerName});

    socket.once('playerId', (data) {
      if (data != null && data['playerId'] != null) {
        completer.complete(data['playerId']);
      } else {
        completer.completeError('Player ID not found.');
      }
    });

    return completer.future;
  }

  void disconnect() {
    print("GameService: Disconnecting from Socket.IO server");
    socket.disconnect();
  }

  /// Helper to log the alphanumeric position
  void _logPlayerPosition(Map<String, dynamic> data) {
    if (data.containsKey('position') && data['position'] is Map) {
      final position = data['position'];
      final x = position['x'] ?? 0;
      final y = position['y'] ?? 0;
      final alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
      final formattedPosition = "${alphabet[x]}${y + 1}";
      print("GameService: Player's current position: $formattedPosition");
    }
  }
}
