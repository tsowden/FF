import 'package:flutter/material.dart';
import '../services/game_service.dart';
import '../styles/app_theme.dart';

class GameScreen extends StatefulWidget {
  final String gameId;
  final String playerName;
  final String playerId; // Ajout de playerId
  final GameService gameService;
  final Map<String, dynamic> initialData;

  const GameScreen({
    Key? key,
    required this.gameId,
    required this.playerName,
    required this.playerId, // Ajout de playerId
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

  Map<String, bool> validMoves = {
    'canMoveForward': false,
    'canMoveLeft': false,
    'canMoveRight': false,
  };

  String _formatPosition(Map<String, dynamic> position) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    int x = position['x'] ?? -1;
    int y = position['y'] ?? -1;

    if (x < 0 || x >= alphabet.length || y < 0) {
      return "Position invalide";
    }

    String letter = alphabet[x];
    String number = (y + 1).toString(); // +1 pour commencer à 1
    return '$letter$number';
  }




  Map<String, Map<String, dynamic>> playerPositions = {};
  List<List<dynamic>> maze = [];

  @override
  void initState() {
    super.initState();

    _gameService = widget.gameService;

    print("GameScreen: Initialisation pour la partie ${widget.gameId}");

    // Vérifiez et initialisez les données de la carte et des joueurs
    maze = widget.initialData['maze'] != null
        ? List<List<dynamic>>.from(widget.initialData['maze'])
        : [];
    List<dynamic> players = widget.initialData['players'] != null
        ? List<dynamic>.from(widget.initialData['players'])
        : [];

    for (var player in players) {
      String playerId = player['playerId'];
      Map<String, dynamic> position = player['position'];
      if (position['x'] != null && position['y'] != null) {
        playerPositions[playerId] = {
          'position': position,
          'orientation': player['orientation'],
        };
      } else {
        print("GameScreen: Invalid position for player $playerId");
      }
    }

    _gameService.onCurrentPlayers((players) {
    setState(() {
      for (var player in players) {
        String playerId = player['playerId'];
        Map<String, dynamic> position = player['position'];
        if (position['x'] != null && position['y'] != null) {
          playerPositions[playerId] = {
            'position': position,
            'orientation': player['orientation'],
          };
        } else {
          print("GameScreen: Invalid position for player $playerId");
        }
      }
    });
  });


    _handleNewTurn(widget.initialData);

    // Configurer les écouteurs pour les événements
    _gameService.onActivePlayerChanged((data) {
      print("GameScreen: Joueur actif changé avec les données : $data");
      _handleNewTurn(data);
    });

    _gameService.onStartGame((data) {
      print("GameScreen: Jeu démarré avec les données : $data");
      _handleNewTurn(data);
    });

    _gameService.onCardDrawn((data) {
      print("GameScreen: Carte piochée avec les données : $data");
      _handleCardDrawn(data);
    });

    _gameService.getActivePlayer(widget.gameId);

    _gameService.onActivePlayerReceived((activePlayerName) {
      print("GameScreen: Joueur actif reçu via getActivePlayer : $activePlayerName");
      setState(() {
        this.activePlayerName = activePlayerName;
        this.isPlayerActive = activePlayerName == widget.playerName;
      });
    });

    // Écouter les mises à jour de position
    _gameService.onPositionUpdate((data) {
      setState(() {
        String playerId = data['playerId'];
        playerPositions[playerId] = {
          'position': data['position'],
          'orientation': data['orientation'],
        };

        if (playerId == widget.playerId) {
          String formattedPosition = _formatPosition(data['position']);
          print("GameScreen: ${widget.playerName} moved to $formattedPosition, orientation: ${data['orientation']}");

          _gameService.getValidMoves(widget.gameId, widget.playerId, (moves) {
            _updateValidMoves(moves);
          });
        }
      });
    });


    _gameService.onValidMovesReceived((data) {
      print("GameScreen: Mouvements valides reçus : $data");
      _updateValidMoves({
        'canMoveForward': data['canMoveForward'] ?? false,
        'canMoveLeft': data['canMoveLeft'] ?? false,
        'canMoveRight': data['canMoveRight'] ?? false,
      });
    });


    // Écouter les erreurs de mouvement
    _gameService.onMoveError((message) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
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

      // Mettre à jour les positions des joueurs si elles sont disponibles dans les données
      if (data['players'] != null) {
        List<dynamic> players = data['players'];
        for (var player in players) {
          String playerId = player['playerId'];
          Map<String, dynamic> position = player['position'];
          if (position['x'] != null && position['y'] != null) {
            playerPositions[playerId] = {
              'position': position,
              'orientation': player['orientation'],
            };
          } else {
            print("GameScreen: Invalid position for player $playerId");
          }
        }
      }

      if (isPlayerActive) {
        descriptionToDisplay = data['cardDescription'];

        // Request valid moves when it's the player's turn
        _gameService.getValidMoves(widget.gameId, widget.playerId, (moves) {
          _updateValidMoves(moves);
        });

        // Log position at the beginning of the turn
        final playerPosition = playerPositions[widget.playerId]?['position'];
        if (playerPosition != null) {
          String formattedPosition = _formatPosition(playerPosition);
          print("GameScreen: Current position of player ${widget.playerName}: $formattedPosition");
        } else {
          print("GameScreen: Position not found for player ${widget.playerName}");
        }
      }
    });
  }


  void _updateValidMoves(Map<String, bool> moves) {
    setState(() {
      validMoves = moves;
    });
  }



  // Widget buildMaze() {
  //   if (maze.isEmpty) {
  //     return Center(child: Text('Chargement de la carte...'));
  //   }
  //   int rows = maze.length;
  //   int cols = maze[0].length;

  //   return Container(
  //     height: MediaQuery.of(context).size.height * 0.4,
  //     child: GridView.builder(
  //       physics: NeverScrollableScrollPhysics(),
  //       gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
  //         crossAxisCount: cols,
  //       ),
  //       itemCount: rows * cols,
  //       itemBuilder: (context, index) {
  //         int x = index % cols;
  //         int y = index ~/ cols;
  //         bool isWall = !maze[y][x]['accessible'];

  //         // Vérifier si un joueur est sur cette case
  //         Widget content = Container();
  //         playerPositions.forEach((playerId, data) {
  //           if (data['position']['x'] == x && data['position']['y'] == y) {
  //             content = Icon(
  //               Icons.person,
  //               color: playerId == widget.playerName ? Colors.blue : Colors.red,
  //               size: 20,
  //             );
  //           }
  //         });

  //         return Container(
  //           decoration: BoxDecoration(
  //             color: isWall ? Colors.black : Colors.white,
  //             border: Border.all(color: Colors.grey),
  //           ),
  //           child: Center(child: content),
  //         );
  //       },
  //     ),
  //   );
  // }

  Widget buildMovementControls() {
    if (!isPlayerActive) return Container();

    return Column(
      children: [
        if (validMoves['canMoveForward'] == true)
          ElevatedButton(
            onPressed: () => _gameService.movePlayer(widget.gameId, widget.playerId, 'forward'),
            child: Text('Avancer'),
            style: ElevatedButton.styleFrom(primary: AppTheme.greenButton),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (validMoves['canMoveLeft'] == true)
              ElevatedButton(
                onPressed: () => _gameService.movePlayer(widget.gameId, widget.playerId, 'left'),
                child: Text('Tourner à gauche'),
                style: ElevatedButton.styleFrom(primary: AppTheme.greenButton),
              ),
            SizedBox(width: 10),
            if (validMoves['canMoveRight'] == true)
              ElevatedButton(
                onPressed: () => _gameService.movePlayer(widget.gameId, widget.playerId, 'right'),
                child: Text('Tourner à droite'),
                style: ElevatedButton.styleFrom(primary: AppTheme.greenButton),
              ),
          ],
        ),
      ],
    );
  }

  @override
Widget build(BuildContext context) {
  final screenHeight = MediaQuery.of(context).size.height;
  final screenWidth = MediaQuery.of(context).size.width;

  return Scaffold(
    body: Stack(
      children: [
        Container(decoration: AppTheme.backgroundDecoration()),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Bloc défilable pour les widgets principaux
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Titre
                      Padding(
                        padding: EdgeInsets.only(bottom: screenHeight * 0.02),
                        child: Text(
                          isPlayerActive
                              ? "C'est votre tour !"
                              : activePlayerName != null
                                  ? "Tour de : $activePlayerName"
                                  : "Aucun joueur actif.",
                          style: Theme.of(context).textTheme.headline6?.copyWith(
                                color: isPlayerActive
                                    ? Colors.green
                                    : AppTheme.greenButton,
                                fontWeight: FontWeight.bold,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      // Image
                      if (cardImage != null)
                        Padding(
                          padding: EdgeInsets.only(bottom: screenHeight * 0.02),
                          child: SizedBox(
                            height: screenHeight * 0.25,
                            child: Image.asset(
                              'assets/images/$cardImage',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      // Nom et description
                      if (cardName != null || descriptionToDisplay != null)
                        Padding(
                          padding: EdgeInsets.only(bottom: screenHeight * 0.02),
                          child: Column(
                            children: [
                              if (cardName != null)
                                Text(
                                  cardName!,
                                  style: TextStyle(
                                    fontSize: 24,
                                    color: AppTheme.greenButton,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Nunito',
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              if (descriptionToDisplay != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    descriptionToDisplay!,
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: AppTheme.greenButton,
                                      fontFamily: 'Nunito',
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      // Boutons de mouvement
                      if (isPlayerActive)
                        Padding(
                          padding: EdgeInsets.only(bottom: screenHeight * 0.02),
                          child: Column(
                            children: [
                              if (validMoves['canMoveForward'] == true)
                                ElevatedButton(
                                  onPressed: () => _gameService.movePlayer(
                                      widget.gameId, widget.playerId, 'forward'),
                                  child: Text('Avancer'),
                                  style: ElevatedButton.styleFrom(
                                      primary: AppTheme.greenButton),
                                ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (validMoves['canMoveLeft'] == true)
                                    ElevatedButton(
                                      onPressed: () => _gameService.movePlayer(
                                          widget.gameId,
                                          widget.playerId,
                                          'left'),
                                      child: Text('Tourner à gauche'),
                                      style: ElevatedButton.styleFrom(
                                          primary: AppTheme.greenButton),
                                    ),
                                  SizedBox(width: 10),
                                  if (validMoves['canMoveRight'] == true)
                                    ElevatedButton(
                                      onPressed: () => _gameService.movePlayer(
                                          widget.gameId,
                                          widget.playerId,
                                          'right'),
                                      child: Text('Tourner à droite'),
                                      style: ElevatedButton.styleFrom(
                                          primary: AppTheme.greenButton),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Bouton de fin du tour
              if (isPlayerActive)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
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