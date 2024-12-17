import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../styles/app_theme.dart';
import 'lobby_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();

  Future<void> _createGame() async {
    print('HomeScreen: Bouton "Create a game" cliqué');

    final playerName = await _showInputDialog(
      title: 'Create a game',
      hint: 'Enter your name (max 10 letters)',
    );

    print('HomeScreen: playerName saisi pour "Create game" = $playerName');

    if (playerName != null && _validatePlayerName(playerName)) {
      try {
        print('HomeScreen: Appel API createGame(playerName=$playerName)');
        final result = await _apiService.createGame(playerName);

        if (result != null) {
          print('HomeScreen: createGame OK -> gameId=${result['gameId']}, playerId=${result['playerId']}');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LobbyScreen(
                gameId: result['gameId']!,
                playerId: result['playerId']!,
                playerName: playerName,
                isHost: true,
              ),
            ),
          );
        } else {
          print('HomeScreen: createGame renvoie null, erreur ?');
          _showErrorDialog('Erreur lors de la création de la partie.');
        }
      } catch (e) {
        print('HomeScreen: Exception lors de la création de la partie : $e');
        _showErrorDialog('Erreur lors de la création de la partie.');
      }
    }
  }

  Future<void> _joinGame() async {
    print('HomeScreen: Bouton "Join a game" cliqué');

    final gameId = await _showInputDialog(
      title: 'Join a game',
      hint: 'Enter the game code',
    );

    print('HomeScreen: gameId saisi pour "Join game" = $gameId');

    if (gameId != null && gameId.isNotEmpty) {
      final playerName = await _showInputDialog(
        title: 'Name',
        hint: 'Enter your name (max 10 letters)',
      );

      print('HomeScreen: playerName saisi pour "Join game" = $playerName');

      if (playerName != null && _validatePlayerName(playerName)) {
        try {
          print('HomeScreen: Appel API joinGame(gameId=$gameId, playerName=$playerName)');
          final result = await _apiService.joinGame(gameId, playerName);

          if (result != null) {
            print('HomeScreen: joinGame OK -> playerId=${result['playerId']}');
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LobbyScreen(
                  gameId: gameId,
                  playerId: result['playerId']!,
                  playerName: playerName,
                  isHost: false,
                ),
              ),
            );
          } else {
            print('HomeScreen: joinGame renvoie null, erreur ?');
            _showErrorDialog('Erreur lors de la connexion à la partie.');
          }
        } catch (e) {
          print('HomeScreen: Exception lors de la connexion à la partie : $e');
          _showErrorDialog('Erreur lors de la connexion à la partie.');
        }
      }
    }
  }

  Future<String?> _showInputDialog({
    required String title,
    required String hint,
  }) async {
    final TextEditingController controller = TextEditingController();

    return await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: hint),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, controller.text.trim());
              },
              child: Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  bool _validatePlayerName(String name) {
    final regex = RegExp(r'^[a-zA-Z0-9\-]{1,10}$');
    if (!regex.hasMatch(name)) {
      _showErrorDialog(
          'Invalid nickname. Use only letters, digits, or "-".');
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Fond commun
          Container(
            decoration: AppTheme.backgroundDecoration(),
          ),
          // Titre
          Positioned(
            top: screenHeight * 0.15,
            left: screenWidth * 0.05,
            right: screenWidth * 0.05,
            child: Center(
              child: Text(
                'Funky Foxes',
                style: Theme.of(context).textTheme.headline1,
              ),
            ),
          ),
          // Logo
          Positioned(
            top: screenHeight * 0.2,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/images/logo-renard.png',
              height: screenHeight * 0.4,
              width: screenWidth * 0.4,
              fit: BoxFit.contain,
            ),
          ),
          // Boutons
          Positioned(
            bottom: screenHeight * 0.15,
            left: screenWidth * 0.1,
            right: screenWidth * 0.1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppTheme.customButton(
                  label: 'Create a game',
                  onPressed: _createGame,
                ),
                SizedBox(height: screenHeight * 0.03),
                AppTheme.customButton(
                  label: 'Join a game',
                  onPressed: _joinGame,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
