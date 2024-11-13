import 'package:flutter/material.dart';
import '../services/game_service.dart';

class LobbyScreen extends StatefulWidget {
  final String gameId;
  final String playerName;

  LobbyScreen({required this.gameId, required this.playerName});

  @override
  _LobbyScreenState createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final GameService _gameService = GameService();
  List<String> players = [];

  @override
  void initState() {
    super.initState();

    // Connecter le service WebSocket et rejoindre la salle de jeu
    _gameService.connectToGame(widget.gameId);

    // Ajouter le joueur actuel au lobby
    players.add(widget.playerName);


    // Écouter l'événement `currentPlayers` pour obtenir la liste complète des joueurs actuels
    _gameService.socket.on('currentPlayers', (data) {
      print("Données reçues dans 'currentPlayers': $data"); // Log pour vérifier la réception
      setState(() {
        players = List<String>.from(data.map((player) => player['playerName']));
      });
      print("Liste des joueurs après mise à jour dans 'currentPlayers': $players"); // Log pour vérifier la mise à jour
    });

    _gameService.joinRoom(widget.gameId);

    // Écouter l'événement `playerJoined` pour ajouter le nouveau joueur
    _gameService.socket.on('playerJoined', (data) {
      print("Données reçues dans 'playerJoined': $data"); // Log pour vérifier la réception
      setState(() {
        if (!players.contains(data['playerName'])) {
          players.add(data['playerName']);
        }
      });
      print("Liste des joueurs après mise à jour dans 'playerJoined': $players"); // Log pour vérifier la mise à jour
    });
  }

  @override
  void dispose() {
    _gameService.disconnect(); // Déconnexion du WebSocket lors de la fermeture
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Lobby - Code: ${widget.gameId}')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Code de la partie: ${widget.gameId}',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text(
              'Pseudo: ${widget.playerName}',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 20),
            Text(
              'En attente des autres joueurs...',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: players.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(players[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
