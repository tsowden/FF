// ignore_for_file: avoid_print

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
  // ------------------------------------------------------
  // FIELDS
  // ------------------------------------------------------
  late final GameService _gameService;

  // Player & movement
  String? activePlayerName;
  bool isPlayerActive = false;
  String turnState = 'movement';
  int _berries = 0;

  // Card
  String? descriptionToDisplay;
  String? cardImage;
  String? cardName;
  String? cardCategory; // Challenge, Quiz, etc.

  // Challenge
  List<String> betOptions = [];
  String? majorityVote;

  // ------------------------------------------------------
  // QUIZ
  // ------------------------------------------------------
  List<String> _quizThemes = []; 
  bool _isQuizCard = false;
  bool _isQuizInProgress = false;

  int? _currentQuestionIndex;
  String? _currentQuestionDescription;
  List<dynamic> _currentQuestionOptions = [];

  bool? _wasAnswerCorrect; 
  String? _correctAnswer;
  int _quizCorrectAnswers = 0;
  int _quizTotalQuestions = 0;
  int _quizEarnedBerries = 0;
  String? _lastGivenAnswer;

  // Messages transitoires
  Map<String, String> playerMessages = {}; 
  List<bool> slotsOccupied = [false, false, false, false];
  double _messageOpacity = 0.0;

  // Valid moves
  Map<String, bool> validMoves = {
    'canMoveForward': false,
    'canMoveLeft': false,
    'canMoveRight': false,
  };

  // ------------------------------------------------------
  // INIT
  // ------------------------------------------------------
  @override
  void initState() {
    super.initState();

    _gameService = widget.gameService;
    print("GameScreen: Initialisation pour le jeu ${widget.gameId}");

    // Traitement du premier "tour"
    _handleNewTurn(widget.initialData);

    // ------------------------------------------------------
    // LISTENERS (Challenge, etc.)
    // ------------------------------------------------------
    _gameService.onTurnStarted((data) {
      _handleNewTurn(data);
    });

    _gameService.onCardDrawn((data) {
      _handleCardDrawn(data);
    });

    _gameService.onTurnStateChanged((data) {
      setState(() {
        turnState = data['turnState'] ?? turnState;

        if (data['betOptions'] != null) {
          betOptions = List<String>.from(data['betOptions']);
        }

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
      print("DEBUG - onChallengeResult data: $data");

      setState(() {
        turnState = 'result';
        if (data['majorityVote'] != null) {
          majorityVote = data['majorityVote'];
        }

        if (data['rewards'] != null) {
          final rewards = data['rewards'] as List<dynamic>;
          final me = rewards.firstWhere(
            (r) => r['playerName'] == widget.playerName,
            orElse: () => null,
          );
          if (me != null && me['berries'] != null) {
            _berries = me['berries'];
          }
        }
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
      print("DEBUG - onBetPlaced: Bet data received: $data");

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

      print("DEBUG - Message à afficher : $message");
      
      if (isPlayerActive) {
        _showTransientMessage(playerName, message);
      }
    });

    // ------------------------------------------------------
    // LISTENERS (Quiz)
    // ------------------------------------------------------
    _gameService.onQuizStarted((data) {
      setState(() {
        _isQuizInProgress = true;
        turnState = 'quizInProgress';
        _currentQuestionIndex = null;
        _currentQuestionDescription = null;
        _currentQuestionOptions = [];
        _wasAnswerCorrect = null;
        _correctAnswer = null;
        _lastGivenAnswer = null;
      });
    });

    _gameService.onQuizQuestion((data) {
      setState(() {
        _currentQuestionIndex = data['questionIndex'];
        _currentQuestionDescription = data['questionDescription'];
        _currentQuestionOptions = data['questionOptions'];
        _wasAnswerCorrect = null;
        _correctAnswer = null;
      });
    });

    _gameService.onQuizAnswerResult((data) {
      setState(() {
        _correctAnswer = data['correctAnswer'];
        _wasAnswerCorrect = data['isCorrect']; 
      });
    });

    _gameService.onQuizEnd((data) {
      setState(() {
        _quizCorrectAnswers = data['correctAnswers'];
        _quizTotalQuestions = data['totalQuestions'];

        // Vérifie si les berries sont pour le joueur local
        if (data['playerId'] == widget.playerId) {
          int newlyEarned = data['earnedBerries'] ?? 0;
          _berries += newlyEarned; // Ajoute les berries au joueur local
          _quizEarnedBerries = newlyEarned;
        }

        _isQuizInProgress = false;
        turnState = 'quizResult';
      });
    });

  }

  // ------------------------------------------------------
  // METHODS
  // ------------------------------------------------------
  void _handleNewTurn(Map<String, dynamic> data) {
    setState(() {
      activePlayerName = data['activePlayerName'];
      isPlayerActive = (activePlayerName == widget.playerName);
      turnState = data['turnState'] ?? 'movement';

      // On reset tout ce qui est lié à la carte
      descriptionToDisplay = null;
      cardName = null;
      cardImage = null;
      betOptions = [];
      cardCategory = null;
      majorityVote = null;

      // Quiz
      _isQuizCard = false;
      _quizThemes = [];

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

      if (cardCategory == 'Quiz') {
        _isQuizCard = true;
        final themeString = data['cardTheme'] ?? data['card_theme'] ?? '';
        if (themeString.isNotEmpty) {
          // Convertit en List<String>
          _quizThemes = List<String>.from(
            themeString.split(';').map((s) => s.trim()),
          );
        }
      } else {
        _isQuizCard = false;
        _quizThemes = [];
      }

      // Description
      String? passiveDescription = data['cardDescriptionPassive'];
      if (passiveDescription != null && passiveDescription.contains('{activePlayerName}')) {
        passiveDescription = passiveDescription.replaceAll('{activePlayerName}', activePlayerName ?? '');
      }

      if (isPlayerActive) {
        descriptionToDisplay = data['cardDescription'];
      } else {
        descriptionToDisplay = passiveDescription;
      }
    });
  }

  void _updateValidMoves(Map<String, bool> moves) {
    setState(() {
      validMoves = moves;
    });
  }

  void _showTransientMessage(String playerName, String message) {
    int? availableSlot = slotsOccupied.indexWhere((occupied) => !occupied);

    if (availableSlot != -1) {
      setState(() {
        slotsOccupied[availableSlot] = true;
        playerMessages[playerName] = message;
        _messageOpacity = 1.0;
      });

      // Attente avant fondu
      Future.delayed(const Duration(seconds: 1), () {
        if (!mounted) return;
        setState(() {
          _messageOpacity = 0.0;
        });

        // Retire le message après 1s
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            setState(() {
              slotsOccupied[availableSlot] = false;
              playerMessages.remove(playerName);
            });
          }
        });
      });
    } else {
      print("DEBUG: Aucun emplacement libre pour afficher le message.");
    }
  }

  // ------------------------------------------------------
  // BUILD: ROOT
  // ------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final messageWidgets = List.generate(slotsOccupied.length, (index) {
      final playersInSlot = playerMessages.entries.toList();
      if (index < playersInSlot.length) {
        final message = playersInSlot[index].value;
        return AnimatedOpacity(
          opacity: _messageOpacity,
          duration: const Duration(seconds: 1),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 5),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green[900],
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 5,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      } else {
        return const SizedBox();
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(decoration: AppTheme.backgroundDecoration()),

          // Berries en haut à droite
          Positioned(
            top: 40,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.favorite, color: Colors.red),
                  const SizedBox(width: 4),
                  Text("$_berries berries",
                      style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ),

          // Contenu principal (actif vs passif)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: isPlayerActive
                ? buildActivePlayerView()
                : buildPassivePlayerView(),
          ),

          // Messages en overlay
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: messageWidgets,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------
  // BUILD: ACTIVE
  // ------------------------------------------------------
  Widget buildActivePlayerView() {
    if (cardCategory == 'Quiz') {
      return _buildQuizActiveView();
    } else if (cardCategory == 'Challenge') {
      return _buildChallengeActiveView();
    } else {
      return _buildDefaultActiveView();
    }
  }

  Widget _buildChallengeActiveView() {
    switch (turnState) {
      case 'movement':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "IT'S YOUR TURN ! Please continue in the forest.",
              style: AppTheme.themeData.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            buildMovementControls(),
          ],
        );

      case 'cardDrawn':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            buildCardDisplay(),
            const SizedBox(height: 20),
            AppTheme.customButton(
              label: 'Start the challenge',
              onPressed: () => _gameService.startBetting(widget.gameId, widget.playerId),
            ),
          ],
        );

      case 'betting':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Other players are making their predictions...',
              style: AppTheme.themeData.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
          ],
        );

      case 'challengeInProgress':
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Challenge in progres... It's your turn to show what you're capable of !",
                  style: AppTheme.themeData.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );

      case 'result':
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Challenge results : ${majorityVote ?? "No result"}',
                style: AppTheme.themeData.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              AppTheme.customButton(
                label: "End the turn",
                onPressed: () => _gameService.endTurn(widget.gameId),
              ),
            ],
          ),
        );

      default:
        return Container();
    }
  }

  Widget _buildQuizActiveView() {
    switch (turnState) {
      case 'movement':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "IT'S YOUR TURN ! Please continue in the forest.",
              style: AppTheme.themeData.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            buildMovementControls(),
          ],
        );

      case 'cardDrawn':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            buildCardDisplay(),
            const SizedBox(height: 20),
            if (!_isQuizInProgress) ...[
              if (_quizThemes.isNotEmpty) ...[
                Text(
                  'Choose your quiz theme:',
                  style: AppTheme.themeData.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                for (var theme in _quizThemes)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: AppTheme.customButton(
                      label: theme,
                      onPressed: () => _gameService.startQuiz(
                        widget.gameId,
                        widget.playerId,
                        theme,
                      ),
                    ),
                  ),
              ],
            ] else
              buildQuizQuestionView(isActive: true),
          ],
        );

      case 'quizResult':
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Quiz results: $_quizCorrectAnswers / $_quizTotalQuestions',
                style: AppTheme.themeData.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Berries earned: $_quizEarnedBerries',
                style: AppTheme.themeData.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              AppTheme.customButton(
                label: "End the turn",
                onPressed: () => _gameService.endTurn(widget.gameId),
              ),
            ],
          ),
        );

      default:
        if (_isQuizInProgress) {
          return buildQuizQuestionView(isActive: true);
        }
        return Container();
    }
  }

  Widget _buildDefaultActiveView() {
    switch (turnState) {
      case 'movement':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "It's your turn. Move!",
              style: AppTheme.themeData.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            buildMovementControls(),
          ],
        );

      case 'cardDrawn':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            buildCardDisplay(),
            const SizedBox(height: 20),
            AppTheme.customButton(
              label: 'End the turn',
              onPressed: () => _gameService.endTurn(widget.gameId),
            ),
          ],
        );

      default:
        return Container();
    }
  }

  // ------------------------------------------------------
  // BUILD: PASSIVE
  // ------------------------------------------------------
  Widget buildPassivePlayerView() {
    if (cardCategory == 'Quiz') {
      return _buildQuizPassiveView();
    } else if (cardCategory == 'Challenge') {
      return _buildChallengePassiveView();
    } else {
      return _buildDefaultPassiveView();
    }
  }

  Widget _buildChallengePassiveView() {
    switch (turnState) {
      case 'movement':
        return Center(
          child: Text(
            "$activePlayerName is moving in the forest...",
            style: AppTheme.themeData.textTheme.bodyMedium,
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
            const SizedBox(height: 20),
            Text(
              'Make your predictions:',
              style: AppTheme.themeData.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ...betOptions.map((option) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: AppTheme.customButton(
                  label: option,
                  onPressed: () => _gameService.placeBet(widget.gameId, widget.playerId, option),
                ),
              );
            }).toList(),
          ],
        );

      case 'challengeInProgress':
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Challenge in progress. Once $activePlayerName is done, you need to indicate whether the challenge is successful or not. BE HONEST.',
                style: AppTheme.themeData.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                'How does $activePlayerName succeed ?',
                style: AppTheme.themeData.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ...betOptions.map((option) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: AppTheme.customButton(
                    label: option,
                    onPressed: () => _gameService.placeChallengeVote(widget.gameId, widget.playerId, option),
                  ),
                );
              }).toList(),
            ],
          ),
        );

      case 'result':
        return Center(
          child: Text(
            'Challenge results : ${majorityVote ?? "No result"}',
            style: AppTheme.themeData.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        );

      default:
        return Container();
    }
  }

  Widget _buildQuizPassiveView() {
    switch (turnState) {
      case 'movement':
        return Center(
          child: Text(
            "$activePlayerName is moving in the forest...",
            style: AppTheme.themeData.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        );

      case 'cardDrawn':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            buildCardDisplay(),
            const SizedBox(height: 20),
            Text(
              "$activePlayerName is choosing a quiz theme...",
              style: AppTheme.themeData.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        );

      case 'quizResult':
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Quiz results: $_quizCorrectAnswers / $_quizTotalQuestions',
                style: AppTheme.themeData.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Berries earned: $_quizEarnedBerries',
                style: AppTheme.themeData.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );

      default:
        if (_isQuizInProgress) {
          // Le passif voit la question, mais isActive=false => pas de clic
          return buildQuizQuestionView(isActive: false);
        }
        return Container();
    }
  }

  Widget _buildDefaultPassiveView() {
    switch (turnState) {
      case 'movement':
        return Center(
          child: Text(
            "$activePlayerName is moving in the forest...",
            style: AppTheme.themeData.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        );
      case 'cardDrawn':
        return Center(child: buildCardDisplay());
      default:
        return Container();
    }
  }

  // ------------------------------------------------------
  // WIDGETS PARTAGÉS
  // ------------------------------------------------------
  Widget buildQuizQuestionView({bool isActive = true}) {
    if (_currentQuestionIndex == null) {
      return Center(
        child: Text(
          "Loading question...",
          style: AppTheme.themeData.textTheme.bodyMedium,
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Question ${_currentQuestionIndex! + 1}",
          style: AppTheme.themeData.textTheme.bodyMedium,
        ),
        const SizedBox(height: 10),
        if (_currentQuestionDescription != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              _currentQuestionDescription!,
              style: AppTheme.themeData.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        const SizedBox(height: 20),

        // Les 4 (ou plus) propositions
        for (var option in _currentQuestionOptions)
          _buildAnswerButton(option, isActive),

        // On NE met plus de texte "Correct!" ou "Wrong!"
      ],
    );
  }

  Widget _buildAnswerButton(String option, bool isActive) {
    Color btnColor = AppTheme.greenButton;

    // Coloration rouge/vert si c’est le bouton cliqué etc.
    if (_lastGivenAnswer != null && _wasAnswerCorrect != null) {
      if (option == _lastGivenAnswer) {
        if (_wasAnswerCorrect == true && _correctAnswer == option) {
          btnColor = Colors.green;
        } else {
          btnColor = Colors.red;
        }
      }
    }

    final canClick = isActive && _wasAnswerCorrect == null;

    // On appelle `customButton`, en lui passant la `backgroundColor` désirée.
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: AppTheme.customButton(
        label: option,
        onPressed: canClick
            ? () {
                setState(() {
                  _lastGivenAnswer = option;
                });
                _gameService.quizAnswer(widget.gameId, widget.playerId, option);
              }
            : () {},
        backgroundColor: btnColor, // on ajoute un paramètre dans customButton
      ),
    );
  }


  Widget buildCardDisplay() {
    final screenHeight = MediaQuery.of(context).size.height;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
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
      ],
    );
  }

  Widget buildMovementControls() {
    if (!isPlayerActive) return Container();

    return Column(
      children: [
        if (validMoves['canMoveForward'] == true)
          AppTheme.customButton(
            label: 'Move forward',
            onPressed: () => _gameService.movePlayer(widget.gameId, widget.playerId, 'forward'),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (validMoves['canMoveLeft'] == true)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: AppTheme.customButton(
                  label: 'Left',
                  onPressed: () => _gameService.movePlayer(widget.gameId, widget.playerId, 'left'),
                ),
              ),
            if (validMoves['canMoveRight'] == true)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: AppTheme.customButton(
                  label: 'Right',
                  onPressed: () => _gameService.movePlayer(widget.gameId, widget.playerId, 'right'),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
