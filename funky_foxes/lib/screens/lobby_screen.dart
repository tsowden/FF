import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/game_service.dart';
import '../styles/app_theme.dart';
import 'game_screen.dart';

class LobbyScreen extends StatefulWidget {
  final String gameId;
  final String playerName;
  final bool isHost;

  LobbyScreen({required this.gameId, required this.playerName, this.isHost = false});

  @override
  _LobbyScreenState createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  late final GameService _gameService;
  final ImagePicker _imagePicker = ImagePicker();
  File? _playerImage;
  List<String> players = [];
  Map<String, bool> readyStatus = {};
  int readyCount = 0;

  @override
  void initState() {
    super.initState();

    _gameService = GameService();

    print('LobbyScreen: Initialisation pour la partie ${widget.gameId} avec le joueur ${widget.playerName}');

    // Connexion au jeu via Socket.IO
    _gameService.connectToGame(widget.gameId);

    // Écoute des événements
    _gameService.socket.on('currentPlayers', (data) {
      print('LobbyScreen: Événement currentPlayers reçu: $data');
      setState(() {
        players = List<String>.from(data.map((player) => player['playerName']));
        readyStatus.clear();
        for (var player in data) {
          readyStatus[player['playerName']] = player['ready'];
        }
        readyCount = readyStatus.values.where((ready) => ready).length;
      });
    });

    _gameService.socket.on('playerJoined', (data) {
      print('LobbyScreen: Événement playerJoined reçu: $data');
      setState(() {
        if (!players.contains(data['playerName'])) {
          players.add(data['playerName']);
          readyStatus[data['playerName']] = false;
        }
      });
    });

    _gameService.socket.on('readyStatusUpdate', (data) {
      print('LobbyScreen: Événement readyStatusUpdate reçu: $data');
      setState(() {
        readyStatus[data['playerName']] = data['isReady'];
        readyCount = readyStatus.values.where((ready) => ready).length;
      });
    });

    _gameService.socket.on('allPlayersReady', (_) {
      print('LobbyScreen: Événement allPlayersReady reçu');
      if (widget.isHost) _showStartGameDialog();
    });

    _gameService.socket.on('startGame', (_) {
      print('LobbyScreen: Événement startGame reçu. Redirection vers GameScreen...');
      try {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GameScreen(
              gameId: widget.gameId,
              playerName: widget.playerName,
              gameService: _gameService, // Correction : Ajout de gameService
            ),
          ),
        );
      } catch (e) {
        print('LobbyScreen: Erreur lors de la redirection vers GameScreen : $e');
      }
    });

    // Écoute des changements de joueur actif
    _gameService.onActivePlayerChanged((activePlayerName) {
      print('LobbyScreen: Joueur actif changé : $activePlayerName');
    });

    // Rejoindre la salle
    _gameService.joinRoom(widget.gameId);
  }

  @override
  void dispose() {
    // Ne pas déconnecter le socket ici car GameService est partagé
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final XFile? pickedFile = await _imagePicker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _playerImage = File(pickedFile.path);
      });
    }
  }

  void _toggleReadyStatus(bool isReady) {
    print('LobbyScreen: Changement du statut prêt pour ${widget.playerName} à $isReady');
    _gameService.setReadyStatus(widget.gameId, widget.playerName, isReady);
    setState(() {
      readyStatus[widget.playerName] = isReady;
      readyCount = readyStatus.values.where((ready) => ready).length;
    });
  }

  void _showStartGameDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Tous les joueurs sont prêts"),
          content: Text("Voulez-vous lancer la partie ?"),
          actions: [
            TextButton(
              child: Text("Non"),
              onPressed: () {
                print('LobbyScreen: Démarrage de la partie annulé par l\'hôte');
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text("Oui"),
              onPressed: () {
                print('LobbyScreen: L\'hôte a choisi de démarrer la partie');
                _gameService.startGame(widget.gameId);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isReady = readyStatus[widget.playerName] ?? false;

    return Scaffold(
      body: Stack(
        children: [
          // Fond
          Container(
            decoration: AppTheme.backgroundDecoration(),
          ),
          // Contenu
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                SizedBox(height: screenHeight * 0.05),
                // Code de la partie
                Text(
                  'Game code:',
                  style: Theme.of(context).textTheme.bodyText1?.copyWith(
                        fontSize: 20,
                        color: AppTheme.greenButton,
                      ),
                ),
                Text(
                  widget.gameId,
                  style: Theme.of(context).textTheme.headline6?.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                SizedBox(height: screenHeight * 0.03),
                // Cercle contenant l'image ou l'icône
                GestureDetector(
                  onTap: _takePhoto,
                  child: Container(
                    width: screenHeight * 0.15,
                    height: screenHeight * 0.15,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.lightMint,
                      border: Border.all(
                        color: AppTheme.greenButton,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 6,
                          offset: Offset(2, 2),
                        ),
                      ],
                      image: _playerImage != null
                          ? DecorationImage(
                              image: FileImage(_playerImage!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _playerImage == null
                        ? Icon(
                            Icons.camera_alt_outlined,
                            size: screenHeight * 0.07,
                            color: AppTheme.greenButton,
                          )
                        : null,
                  ),
                ),
                SizedBox(height: screenHeight * 0.02),
                // Pseudo du joueur
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.lightMint,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 6,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    widget.playerName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.greenButton,
                      fontFamily: 'Nunito',
                    ),
                  ),
                ),
                SizedBox(height: screenHeight * 0.03),
                // Nombre de joueurs prêts
                Text(
                  'Players ready: $readyCount/${players.length}',
                  style: Theme.of(context).textTheme.bodyText1?.copyWith(
                        fontSize: 18,
                      ),
                ),
                SizedBox(height: screenHeight * 0.03),
                // Liste des joueurs
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.lightMint,
                      border: Border.all(color: AppTheme.greenButton, width: 2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.all(8.0),
                    child: ListView.builder(
                      itemCount: players.length,
                      itemBuilder: (context, index) {
                        final player = players[index];
                        final playerIsReady = readyStatus[player] ?? false;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                player,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: playerIsReady ? Colors.green : Colors.red,
                                ),
                              ),
                              Icon(
                                playerIsReady ? Icons.check_circle : Icons.cancel,
                                color: playerIsReady ? Colors.green : Colors.red,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(height: screenHeight * 0.03),
                // Bouton "Ready"
                AppTheme.customButton(
                  label: isReady ? "Unready" : "Ready!",
                  onPressed: () => _toggleReadyStatus(!isReady),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
