import 'package:flutter/material.dart';
import 'lobby_screen.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _gameIdController = TextEditingController();
  final TextEditingController _playerNameController = TextEditingController();

  Future<void> _createGame() async {
    final playerName = _playerNameController.text;
    if (playerName.isNotEmpty) {
      final response = await _apiService.createGame(playerName);
      if (response != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Code de la partie : ${response['gameId']}'))
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LobbyScreen(
              gameId: response['gameId']!,
              playerName: playerName,
            ),
          ),
        );
      }
    }
  }

  Future<void> _joinGame() async {
    final gameId = _gameIdController.text;
    final playerName = _playerNameController.text;
    if (gameId.isNotEmpty && playerName.isNotEmpty) {
      final playerId = await _apiService.joinGame(gameId, playerName);
      if (playerId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LobbyScreen(
              gameId: gameId,
              playerName: playerName,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Page d\'accueil')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _playerNameController,
              decoration: InputDecoration(labelText: 'Entrez votre pseudo'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _createGame,
              child: Text('Créer une partie'),
            ),
            SizedBox(height: 20),
            TextField(
              controller: _gameIdController,
              decoration: InputDecoration(labelText: 'Code de la partie'),
            ),
            ElevatedButton(
              onPressed: _joinGame,
              child: Text('Rejoindre une partie'),
            ),
          ],
        ),
      ),
    );
  }
}
