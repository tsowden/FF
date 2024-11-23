import 'package:flutter/material.dart';
import '../services/game_service.dart';
import '../styles/app_theme.dart';

class GameScreen extends StatefulWidget {
  final String gameId;
  final String playerName;
  final GameService gameService; // Ajout de gameService

  const GameScreen({
    Key? key,
    required this.gameId,
    required this.playerName,
    required this.gameService, // Ajout de gameService
  }) : super(key: key);

  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GameService _gameService;
  String? activePlayerName;
  bool isPlayerActive = false;
  List<String> events = [];

  @override
  void initState() {
    super.initState();

    _gameService = widget.gameService; // Utilisation de l'instance partagée

    print("GameScreen: Initialisation pour la partie ${widget.gameId}");

    // Écoute de l'événement startGame
    _gameService.onStartGame((activePlayerName) {
      print("GameScreen: Jeu démarré avec le joueur actif : $activePlayerName");
      setState(() {
        this.activePlayerName = activePlayerName;
        this.isPlayerActive = activePlayerName == widget.playerName;
      });
    });

    // Écoute des changements de joueur actif
    _gameService.onActivePlayerChanged((activePlayerName) {
      print("GameScreen: Joueur actif changé : $activePlayerName");
      setState(() {
        this.activePlayerName = activePlayerName;
        this.isPlayerActive = activePlayerName == widget.playerName;
      });
    });

    // Demander le joueur actif actuel
    _gameService.getActivePlayer(widget.gameId);

    // Écoute de la réponse du joueur actif
    _gameService.onActivePlayerReceived((activePlayerName) {
      print("GameScreen: Joueur actif reçu via getActivePlayer : $activePlayerName");
      setState(() {
        this.activePlayerName = activePlayerName;
        this.isPlayerActive = activePlayerName == widget.playerName;
      });
    });
  }

  @override
  void dispose() {
    print("GameScreen: Déconnexion et nettoyage des ressources.");
    // Ne déconnectez pas le socket ici, car il est partagé avec LobbyScreen
    super.dispose();
  }

  void _endTurn() {
    print("GameScreen: Demande de fin de tour émise pour la partie ${widget.gameId}");
    _gameService.endTurn(widget.gameId);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [
          // Fond
          Container(
            decoration: AppTheme.backgroundDecoration(),
          ),
          // Contenu principal
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                SizedBox(height: screenHeight * 0.05),
                // Affichage du joueur actif
                Text(
                  isPlayerActive
                      ? "C'est votre tour !"
                      : (activePlayerName != null
                          ? "Tour de : $activePlayerName"
                          : "Aucun joueur actif."),
                  style: Theme.of(context).textTheme.headline6?.copyWith(
                        color: isPlayerActive ? Colors.green : AppTheme.greenButton,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                SizedBox(height: screenHeight * 0.03),
                // Liste des événements du jeu
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: AppTheme.lightMint,
                      border: Border.all(color: AppTheme.greenButton, width: 2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: ListView.builder(
                      itemCount: events.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            events[index],
                            style: TextStyle(
                              fontSize: 16,
                              color: AppTheme.greenButton,
                              fontFamily: 'Nunito',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(height: screenHeight * 0.03),
                // Bouton "Fin du tour" uniquement pour le joueur actif
                if (isPlayerActive)
                  AppTheme.customButton(
                    label: "Fin du tour",
                    onPressed: _endTurn,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
