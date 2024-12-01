// game_screen.dart

import 'package:flutter/material.dart';
import '../services/game_service.dart';
import '../styles/app_theme.dart';

class GameScreen extends StatefulWidget {
  final String gameId;
  final String playerName;
  final GameService gameService;
  final Map<String, dynamic> initialData; 

  const GameScreen({
    Key? key,
    required this.gameId,
    required this.playerName,
    required this.gameService,
    required this.initialData,
  }) : super(key: key);

  @override
  _GameScreenState createState() => _GameScreenState();
}


class _GameScreenState extends State<GameScreen> {
  late final GameService _gameService;
  String? activePlayerName;
  bool isPlayerActive = false;
  String? descriptionToDisplay;
  String? cardImage;
  String? cardName;

  @override
  void initState() {
    super.initState();

    _gameService = widget.gameService;

    print("GameScreen: Initialisation pour la partie ${widget.gameId}");

    _handleNewTurn(widget.initialData);
    

    // Set up listeners for subsequent events
    _gameService.onActivePlayerChanged((data) {
      print("GameScreen: Joueur actif changé avec les données : $data");
      _handleNewTurn(data);
    });

    _gameService.onStartGame((data) {
      print("GameScreen: Jeu démarré avec les données : $data");
      _handleNewTurn(data);
    });

    _gameService.onActivePlayerChanged((data) {
      print("GameScreen: Joueur actif changé avec les données : $data");
      _handleNewTurn(data);
    });

    _gameService.getActivePlayer(widget.gameId);

    _gameService.onActivePlayerReceived((activePlayerName) {
      print("GameScreen: Joueur actif reçu via getActivePlayer : $activePlayerName");
      setState(() {
        this.activePlayerName = activePlayerName;
        this.isPlayerActive = activePlayerName == widget.playerName;
      });
    });
  }

  void _handleCardDrawn(Map<String, dynamic> data) {
    String newActivePlayerName = data['activePlayerName'];
    String cardDescription = data['cardDescription'];
    String cardDescriptionPassive = data['cardDescriptionPassive'];
    String cardImageName = data['cardImage'];
    String newCardName = data['cardName'];

    setState(() {
      activePlayerName = newActivePlayerName;
      isPlayerActive = newActivePlayerName == widget.playerName;
      cardName = newCardName;
      cardImage = cardImageName;

      if (isPlayerActive) {
        descriptionToDisplay = cardDescription;
      } else {
        descriptionToDisplay = cardDescriptionPassive;
      }
    });
    print("GameScreen: Mise à jour de l'UI avec la nouvelle carte et joueur actif.");

  }



  void _handleNewTurn(Map<String, dynamic> data) {
    setState(() {
      activePlayerName = data['activePlayerName'];
      isPlayerActive = activePlayerName == widget.playerName;
      cardName = data['cardName'];
      cardImage = data['cardImage'];

      if (isPlayerActive) {
        descriptionToDisplay = data['cardDescription'];
      } else {
        descriptionToDisplay = data['cardDescriptionPassive'];
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [
          Container(decoration: AppTheme.backgroundDecoration()),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: screenHeight * 0.05),
                Text(
                  isPlayerActive
                      ? "C'est votre tour !"
                      : activePlayerName != null
                          ? "Tour de : $activePlayerName"
                          : "Aucun joueur actif.",
                  style: Theme.of(context).textTheme.headline6?.copyWith(
                        color: isPlayerActive ? Colors.green : AppTheme.greenButton,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                SizedBox(height: screenHeight * 0.03),
                if (cardImage != null)
                  Center(
                    child: Image.asset(
                      'assets/images/$cardImage',
                      fit: BoxFit.cover,
                    ),
                  ),
                SizedBox(height: 20),
                if (cardName != null)
                  Text(
                    cardName!,
                    style: TextStyle(
                      fontSize: 24,
                      color: AppTheme.greenButton,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Nunito',
                    ),
                  ),
                SizedBox(height: 10),
                if (descriptionToDisplay != null)
                  Text(
                    descriptionToDisplay!,
                    style: TextStyle(
                      fontSize: 18,
                      color: AppTheme.greenButton,
                      fontFamily: 'Nunito',
                    ),
                  ),
                Spacer(),
                if (isPlayerActive)
                  Center(
                    child: AppTheme.customButton(
                      label: "Fin du tour",
                      onPressed: () => _gameService.endTurn(widget.gameId),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}
