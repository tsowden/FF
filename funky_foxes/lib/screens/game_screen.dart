// lib/screens/game_screen.dart

import 'package:flutter/material.dart';
import '../services/game_service.dart';
import '../styles/app_theme.dart';

class GameScreen extends StatefulWidget {
  final String gameId;
  final String playerName;
  final String playerId;
  final GameService gameService;
  final Map<String, dynamic> initialData;

  const GameScreen({
    Key? key,
    required this.gameId,
    required this.playerName,
    required this.playerId,
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
  List<String> betOptions = [];
  String? cardCategory;
  String turnState = 'movement';
  String? majorityVote;

  String? _betMessage;
  double _messageOpacity = 0.0;

  Map<String, bool> validMoves = {
    'canMoveForward': false,
    'canMoveLeft': false,
    'canMoveRight': false,
  };

  @override
  void initState() {
    super.initState();

    _gameService = widget.gameService;
    print("GameScreen: Initialisation pour le jeu ${widget.gameId}");

    _handleNewTurn(widget.initialData);

    _gameService.onTurnStarted((data) {
      _handleNewTurn(data);
    });

    _gameService.onCardDrawn((data) {
      _handleCardDrawn(data);
    });

    _gameService.onTurnStateChanged((data) {
      setState(() {
        turnState = data['turnState'] ?? turnState;
        if (data.containsKey('majorityVote')) {
          majorityVote = data['majorityVote'];
          _gameService.majorityVote = data['majorityVote'];
        }
      });
    });

    _gameService.onValidMovesReceived((data) {
      _updateValidMoves({
        'canMoveForward': data['canMoveForward'] ?? false,
        'canMoveLeft': data['canMoveLeft'] ?? false,
        'canMoveRight': data['canMoveRight'] ?? false,
      });
    });

    _gameService.onMoveError((message) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    });

    _gameService.onChallengeResult((data) {
      setState(() {
        turnState = 'result';
      });
    });

    _gameService.onChallengeVotesUpdated((data) {
      setState(() {
        if (data['isMajorityReached']) {
          turnState = 'result';
          majorityVote = data['majorityVote'];
          _gameService.majorityVote = data['majorityVote'];
        }
      });
    });

    _gameService.onActivePlayerChanged((data) {
      _handleNewTurn(data);
    });

    _gameService.onBetPlaced((data) {
      if (isPlayerActive) {
        final playerName = data['playerName'];
        final bet = data['bet'];
        final index = betOptions.indexOf(bet);
        String message;
        if (index == 0) {
          message = "$playerName ne croit pas en vous.";
        } else if (index == betOptions.length - 1) {
          message = "$playerName mise tout sur vous !";
        } else {
          message = "$playerName croit moyennement en vous.";
        }
        _showTransientMessage(message);
      }
    });
  }

  void _handleNewTurn(Map<String, dynamic> data) {
    setState(() {
      activePlayerName = data['activePlayerName'];
      isPlayerActive = (activePlayerName == widget.playerName);
      turnState = data['turnState'] ?? 'movement';
      descriptionToDisplay = null;
      cardName = null;
      cardImage = null;
      betOptions = [];
      cardCategory = null;
      majorityVote = null;
      _betMessage = null;
      _messageOpacity = 0.0;

      if (isPlayerActive) {
        _gameService.getValidMoves(widget.gameId, widget.playerId, _updateValidMoves);
      }
    });
  }

  void _handleCardDrawn(Map<String, dynamic> data) {
    setState(() {
      activePlayerName = data['activePlayerName'];
      isPlayerActive = (activePlayerName == widget.playerName);
      cardName = data['cardName'];
      cardImage = data['cardImage'];
      cardCategory = data['cardCategory'];
      turnState = data['turnState'];
      betOptions = List<String>.from(data['betOptions'] ?? []);

      if (isPlayerActive) {
        descriptionToDisplay = data['cardDescription'];
      } else {
        descriptionToDisplay = data['cardDescriptionPassive'];
      }
    });
  }

  void _updateValidMoves(Map<String, bool> moves) {
    setState(() {
      validMoves = moves;
    });
  }

  void _showTransientMessage(String message) {
    setState(() {
      _betMessage = message;
      _messageOpacity = 1.0;
    });

    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _messageOpacity = 0.0;
      });
      Future.delayed(const Duration(seconds: 1), () {
        setState(() {
          _betMessage = null;
        });
      });
    });
  }

  Widget buildActivePlayerView() {
    switch (turnState) {
      case 'movement':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("IT'S YOUR TURN ! Please continue in the forest.",
                style: AppTheme.themeData.textTheme.headline6),
            buildMovementControls(),
          ],
        );

      case 'cardDrawn':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            buildCardDisplay(),
            AppTheme.customButton(
              label: 'Start the challenge',
              onPressed: () => _gameService.startBetting(widget.gameId, widget.playerId),
            ),
          ],
        );

      case 'betting':
        return Center(
          child: Text(
            'Other players are making their predictions...',
            style: AppTheme.themeData.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        );

      case 'challengeInProgress':
        return Center(
          child: Text(
            'CHALLENGE IN PROGRESS…',
            style: AppTheme.themeData.textTheme.bodyText1,
            textAlign: TextAlign.center,
          ),
        );

      case 'result':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Challenge results : ${majorityVote ?? "No result"}',
              style: AppTheme.themeData.textTheme.bodyText1,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            AppTheme.customButton(
              label: "End the turn",
              onPressed: () => _gameService.endTurn(widget.gameId),
            ),
          ],
        );

      default:
        return Container();
    }
  }

  Widget buildPassivePlayerView() {
    switch (turnState) {
      case 'movement':
        return Center(
          child: Text(
            "$activePlayerName started exploring the forest again.",
            style: AppTheme.themeData.textTheme.bodyText1,
            textAlign: TextAlign.center,
          ),
        );

      case 'cardDrawn':
        return Center(child: buildCardDisplay());

      case 'betting':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            buildCardDisplay(),
            Text(
              'Make your predictions (10s) :',
              style: AppTheme.themeData.textTheme.bodyText1,
              textAlign: TextAlign.center,
            ),
            ...betOptions.map((option) {
              return AppTheme.customButton(
                label: option,
                onPressed: () => _gameService.placeBet(widget.gameId, widget.playerId, option),
              );
            }).toList(),
          ],
        );

      case 'challengeInProgress':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Challenge in progress. Once $activePlayerName is done, you need to indicate whether the challenge is successful or not.',
              style: AppTheme.themeData.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            Text(
              'How does $activePlayerName succeed ? ',
              style: AppTheme.themeData.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            ...betOptions.map((option) {
              return AppTheme.customButton(
                label: option,
                onPressed: () => _gameService.placeChallengeVote(widget.gameId, widget.playerId, option),
              );
            }).toList(),
          ],
        );

      case 'result':
        return Center(
          child: Text(
            'Challenge results : \n : ${majorityVote ?? "No result"}',
            style: const TextStyle(
              fontSize: 18,
              color: AppTheme.greenButton,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        );

      default:
        return Container();
    }
  }

  Widget buildCardDisplay() {
    final screenHeight = MediaQuery.of(context).size.height;
    return Column(
      children: [
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
        if (cardName != null)
          Text(
            cardName!,
            style: const TextStyle(
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
              style: const TextStyle(
                fontSize: 18,
                color: AppTheme.greenButton,
                fontFamily: 'Nunito',
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  Widget buildMovementControls() {
    if (!isPlayerActive) return Container();

    return Column(
      children: [
        if (validMoves['canMoveForward'] == true)
          ElevatedButton(
            onPressed: () => _gameService.movePlayer(widget.gameId, widget.playerId, 'forward'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.greenButton,
            ),
            child: const Text('Move forward'),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (validMoves['canMoveLeft'] == true)
              ElevatedButton(
                onPressed: () => _gameService.movePlayer(widget.gameId, widget.playerId, 'left'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.greenButton,
                ),
                child: const Text('Left'),
              ),
            const SizedBox(width: 10),
            if (validMoves['canMoveRight'] == true)
              ElevatedButton(
                onPressed: () => _gameService.movePlayer(widget.gameId, widget.playerId, 'right'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.greenButton,
                ),
                child: const Text('Right'),
              ),
          ],
        ),
      ],
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(decoration: AppTheme.backgroundDecoration()),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: isPlayerActive ? buildActivePlayerView() : buildPassivePlayerView(),
          ),
          if (_betMessage != null)
            Positioned(
              top: 50,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: _messageOpacity,
                duration: const Duration(seconds: 1),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.black54,
                    child: Text(
                      _betMessage!,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
