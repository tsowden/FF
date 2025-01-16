// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import '../services/game_service.dart';
import '../styles/app_theme.dart';
import 'dart:convert';

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

  // player info
  String? activePlayerName;
  bool isPlayerActive = false;
  String turnState = 'movement';
  int _berries = 0;
  String? _activePlayerAvatar;

  // rank
  int _myRank = 1;
  int _totalPlayers = 1;

  // card
  String? descriptionToDisplay;
  String? cardImage;
  String? cardName;
  String? cardCategory;

  // challenge & bets
  List<String> betOptions = [];
  String? majorityVote;

  // quiz
  List<dynamic> _quizThemes = [];
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

  Map<String, String> playerMessages = {};
  List<bool> slotsOccupied = [false, false, false, false];
  double _messageOpacity = 0.0;

  // valid moves
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

    // Traite les données initiales reçues depuis le push Navigation:
    _handleNewTurn(widget.initialData);

    // ---------------------------
    // LISTENERS
    // ---------------------------
    // Turn
    _gameService.onTurnStarted((data) => _handleNewTurn(data));
    _gameService.onActivePlayerChanged((data) => _handleNewTurn(data));

    // Card
    _gameService.onCardDrawn((data) => _handleCardDrawn(data));

    // Tour / betOptions
    _gameService.onTurnStateChanged((data) {
      setState(() {
        turnState = data['turnState'] ?? turnState;

        // Parsing défensif de betOptions :
        final rawBetOptions = data['betOptions'];
        if (rawBetOptions is List) {
          betOptions = rawBetOptions.map((e) => e.toString()).toList();
        } else {
          betOptions = [];
        }

        if (data.containsKey('majorityVote')) {
          majorityVote = data['majorityVote'];
          _gameService.majorityVote = data['majorityVote'];
        }
      });
    });

    // Valid moves
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

    // Challenge
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
        if (data['isMajorityReached'] == true) {
          turnState = 'result';
          majorityVote = data['majorityVote'];
          _gameService.majorityVote = data['majorityVote'];
        }
      });
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
      if (isPlayerActive) {
        _showTransientMessage(playerName, message);
      }
    });

    // Quiz
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
        if (data['playerId'] == widget.playerId) {
          int newlyEarned = data['earnedBerries'] ?? 0;
          _berries += newlyEarned;
          _quizEarnedBerries = newlyEarned;
        }
        _isQuizInProgress = false;
        turnState = 'quizResult';
      });
    });

    // gameInfos pour rang + avatar
    _gameService.onGameInfos((data) {
      print("GameScreen: onGameInfos => $data");

      final playersData = data['players'] ?? [];

      // On récupère la liste de joueurs, sous forme d'objets
      List<Map<String, dynamic>> playersList = [];
      if (playersData is List) {
        playersList = playersData.map((p) => p as Map<String, dynamic>).toList();
      }

      // 1) Récupère l'active player name
      final activeName = data['activePlayerName'] as String?;

      // 2) Trouver le joueur actif pour son avatar
      if (activeName != null) {
        final activePlayerData = playersList.firstWhere(
          (p) => p['playerName'] == activeName,
          orElse: () => <String, dynamic>{},
        );
        if (activePlayerData.isNotEmpty) {
          final avatarB64 = activePlayerData['avatarBase64'] as String?;
          if (avatarB64 != null && avatarB64.isNotEmpty) {
            setState(() {
              _activePlayerAvatar = avatarB64;
            });
          } else {
            // Si vide
            setState(() {
              _activePlayerAvatar = '';
            });
          }
        }
        setState(() {
          activePlayerName = activeName;
        });
      }

      // 3) Trouver "me"
      final me = playersList.firstWhere(
        (p) => p['playerId'] == widget.playerId,
        orElse: () => <String, dynamic>{},
      );
      if (me.isNotEmpty) {
        _berries = me['berries'] ?? 0;
        _myRank = me['rank'] ?? 1;
      }

      // 4) Nombre total de joueurs
      setState(() {
        _totalPlayers = playersList.length;
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

      descriptionToDisplay = null;
      cardName = null;
      cardImage = null;
      betOptions = [];
      cardCategory = null;
      majorityVote = null;

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

      final rawBetOptions = data['betOptions'];
      if (rawBetOptions is List) {
        betOptions = rawBetOptions.map((e) => e.toString()).toList();
      } else {
        betOptions = [];
      }

      if (cardCategory == 'Quiz') {
        _isQuizCard = true;
        final themeString = data['cardTheme'] ?? '';
        print('DEBUG: cardTheme received = $themeString');
        if (themeString.isNotEmpty) {
          _quizThemes = themeString.split(';').map((s) => s.trim()).toList();
        }
      } else {
        _isQuizCard = false;
        _quizThemes = [];
      }

      String? passiveDescription = data['cardDescriptionPassive'];
      if (passiveDescription != null &&
          passiveDescription.contains('{activePlayerName}')) {
        passiveDescription = passiveDescription.replaceAll(
          '{activePlayerName}',
          activePlayerName ?? '',
        );
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
    final availableSlot = slotsOccupied.indexWhere((occupied) => !occupied);
    if (availableSlot != -1) {
      setState(() {
        slotsOccupied[availableSlot] = true;
        playerMessages[playerName] = message;
        _messageOpacity = 1.0;
      });

      Future.delayed(const Duration(seconds: 1), () {
        if (!mounted) return;
        setState(() => _messageOpacity = 0.0);

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

  String _rankSuffix(int rank) {
    if (rank == 1) return "1st";
    if (rank == 2) return "2nd";
    if (rank == 3) return "3rd";
    return "${rank}th";
  }

  // ------------------------------------------------------
  // BUILD
  // ------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // prepare messages
    final messageWidgets = List.generate(slotsOccupied.length, (index) {
      final playersInSlot = playerMessages.entries.toList();
      if (index < playersInSlot.length) {
        final message = playersInSlot[index].value;
        return AnimatedOpacity(
          opacity: _messageOpacity,
          duration: const Duration(seconds: 1),
          child: Container(
            margin: EdgeInsets.symmetric(vertical: screenHeight * 0.005),
            padding: EdgeInsets.all(screenWidth * 0.03),
            decoration: AppTheme.transientMessageBoxDecoration(screenWidth * 0.02),
            child: Text(
              message,
              style: AppTheme.transientMessageTextStyle(screenWidth * 0.04),
              textAlign: TextAlign.center,
            ),
          ),
        );
      }
      return const SizedBox();
    });

    return Scaffold(
      body: Stack(
        children: [
          // 1) background
          Container(decoration: AppTheme.backgroundDecoration()),

          // 2) left header
          Positioned(
            top: screenHeight * 0.06,
            left: screenWidth * 0.04,
            child: _buildYourInfo(context),
          ),

          // 3) right header
          Positioned(
            top: screenHeight * 0.06,
            right: screenWidth * 0.04,
            child: _buildActivePlayerInfo(context),
          ),

          // 4) main content
          Padding(
            padding: EdgeInsets.only(
              top: screenHeight * 0.20,
              left: screenWidth * 0.03,
              right: screenWidth * 0.03,
              bottom: screenHeight * 0.08,
            ),
            child: SingleChildScrollView(
              child: isPlayerActive
                  ? buildActivePlayerView()
                  : buildPassivePlayerView(),
            ),
          ),

          // 5) messages in the bottom
          Positioned(
            bottom: screenHeight * 0.08,
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
  // BUILD "ABOUT YOU" & "ACTIVE PLAYER"
  // ------------------------------------------------------
  Widget _buildYourInfo(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final circleSize = screenWidth * 0.18;
    final maxBerries = 30;
    final rankStr = "${_rankSuffix(_myRank)} out of $_totalPlayers";

    return Container(
      width: circleSize,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            "About you:",
            textAlign: TextAlign.center,
            style: AppTheme.topLabelStyle(context, 0.03),
          ),
          SizedBox(height: screenHeight * 0.004),
          Container(
            width: circleSize,
            height: circleSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.darkerGreen,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "$_berries/$maxBerries",
                  style: AppTheme.circleNumberStyle(circleSize),
                ),
                SizedBox(height: circleSize * 0.05),
                Image.asset(
                  'assets/images/berry1.png',
                  width: circleSize * 0.25,
                  height: circleSize * 0.22,
                ),
              ],
            ),
          ),
          SizedBox(height: screenHeight * 0.005),
          Text(
            rankStr,
            textAlign: TextAlign.center,
            style: AppTheme.rankStyle(context, 0.03),
          ),
        ],
      ),
    );
  }

  Widget _buildActivePlayerInfo(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final circleSize = screenWidth * 0.18;

    Widget avatarWidget;
    if (_activePlayerAvatar != null && _activePlayerAvatar!.isNotEmpty) {
      final bytes = base64Decode(_activePlayerAvatar!);
      print("DEBUG: Decoding avatar, length = ${_activePlayerAvatar!.length}");
      avatarWidget = CircleAvatar(
        radius: circleSize * 0.5,
        backgroundImage: MemoryImage(bytes),
      );
    } else {
      print("DEBUG: _activePlayerAvatar is null or empty => showing default icon");
      avatarWidget = Icon(
        Icons.person,
        size: circleSize * 0.5,
        color: AppTheme.darkerGreen,
      );
    }

    return Container(
      width: circleSize,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            "Turn:",
            textAlign: TextAlign.center,
            style: AppTheme.topLabelStyle(context, 0.03),
          ),
          SizedBox(height: screenHeight * 0.004),
          Container(
            width: circleSize,
            height: circleSize,
            child: avatarWidget,
          ),
          SizedBox(height: screenHeight * 0.004),
          Text(
            "${activePlayerName ?? '???'} is playing",
            textAlign: TextAlign.center,
            style: AppTheme.topLabelStyle(context, 0.03),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------
  // BUILD: ACTIVE / PASSIVE
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

  Widget buildPassivePlayerView() {
    if (cardCategory == 'Quiz') {
      return _buildQuizPassiveView();
    } else if (cardCategory == 'Challenge') {
      return _buildChallengePassiveView();
    } else {
      return _buildDefaultPassiveView();
    }
  }

  // ------------------------------------------------------
  // CHALLENGE
  // ------------------------------------------------------
  Widget _buildChallengeActiveView() {
    final screenHeight = MediaQuery.of(context).size.height;
    switch (turnState) {
      case 'movement':
        return Container(
          width: double.infinity,
          alignment: Alignment.center,
          margin: EdgeInsets.only(top: screenHeight * 0.25),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "IT'S YOUR TURN ! Please continue in the forest.",
                style: AppTheme.themeData.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              buildMovementControls(),
            ],
          ),
        );
      case 'cardDrawn':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            buildCardDisplay(),
            const SizedBox(height: 16),
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
            const SizedBox(height: 16),
          ],
        );
      case 'challengeInProgress':
        return Padding(
          padding: const EdgeInsets.all(12.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Challenge in progres... It's your turn to show what you're capable of !",
                  style: AppTheme.themeData.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
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
              const SizedBox(height: 16),
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

  Widget _buildChallengePassiveView() {
    final screenHeight = MediaQuery.of(context).size.height;
    switch (turnState) {
      case 'movement':
        return Container(
          width: double.infinity,
          alignment: Alignment.center,
          margin: EdgeInsets.only(top: screenHeight * 0.25),
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
            const SizedBox(height: 16),
            Text(
              'Make your predictions:',
              style: AppTheme.themeData.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ...betOptions.map((option) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
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
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Challenge in progress. Once $activePlayerName is done, you need to indicate whether the challenge is successful or not. BE HONEST.',
                style: AppTheme.themeData.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'How does $activePlayerName succeed ?',
                style: AppTheme.themeData.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Les options de challenge vote :
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

  // ------------------------------------------------------
  // QUIZ
  // ------------------------------------------------------
  Widget _buildQuizActiveView() {
    final screenHeight = MediaQuery.of(context).size.height;
    switch (turnState) {
      case 'movement':
        return Container(
          width: double.infinity,
          alignment: Alignment.center,
          margin: EdgeInsets.only(top: screenHeight * 0.25),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "IT'S YOUR TURN ! Please continue in the forest.",
                style: AppTheme.themeData.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              buildMovementControls(),
            ],
          ),
        );
      case 'cardDrawn':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            buildCardDisplay(),
            const SizedBox(height: 16),
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
                      onPressed: () => _gameService.startQuiz(widget.gameId, widget.playerId, theme),
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

  Widget _buildQuizPassiveView() {
    final screenHeight = MediaQuery.of(context).size.height;
    switch (turnState) {
      case 'movement':
        return Container(
          width: double.infinity,
          alignment: Alignment.center,
          margin: EdgeInsets.only(top: screenHeight * 0.25),
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
            const SizedBox(height: 16),
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
          return buildQuizQuestionView(isActive: false);
        }
        return Container();
    }
  }

  // ------------------------------------------------------
  // BUILD: DEFAULT
  // ------------------------------------------------------
  Widget _buildDefaultActiveView() {
    final screenHeight = MediaQuery.of(context).size.height;
    switch (turnState) {
      case 'movement':
        return Container(
          width: double.infinity,
          alignment: Alignment.center,
          margin: EdgeInsets.only(top: screenHeight * 0.25),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "It's your turn. Move!",
                style: AppTheme.themeData.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              buildMovementControls(),
            ],
          ),
        );
      case 'cardDrawn':
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            buildCardDisplay(),
            const SizedBox(height: 16),
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

  Widget _buildDefaultPassiveView() {
    final screenHeight = MediaQuery.of(context).size.height;
    switch (turnState) {
      case 'movement':
        return Container(
          width: double.infinity,
          alignment: Alignment.center,
          margin: EdgeInsets.only(top: screenHeight * 0.25),
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
  // BUILD: QUIZ QUESTION
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
        for (var option in _currentQuestionOptions) _buildAnswerButton(option, isActive),
      ],
    );
  }

  Widget _buildAnswerButton(String option, bool isActive) {
    Color btnColor = AppTheme.greenButton;
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

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: AppTheme.customButton(
        label: option,
        onPressed: canClick
            ? () {
                setState(() => _lastGivenAnswer = option);
                _gameService.quizAnswer(widget.gameId, widget.playerId, option);
              }
            : () {},
        backgroundColor: btnColor,
      ),
    );
  }

  // ------------------------------------------------------
  // BUILD: CARD DISPLAY + MOVEMENT
  // ------------------------------------------------------
  Widget buildCardDisplay() {
    final screenHeight = MediaQuery.of(context).size.height;
    // Centrage horizontal
    return Center(
      child: Column(
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
              padding: const EdgeInsets.only(top: 4.0),
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
              padding: EdgeInsets.only(bottom: screenHeight * 0.015),
              child: SizedBox(
                height: screenHeight * 0.25,
                child: Image.asset(
                  'assets/images/$cardImage',
                  fit: BoxFit.contain,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget buildMovementControls() {
    if (!isPlayerActive) return Container();

    return Column(
      children: [
        if (validMoves['canMoveForward'] == true)
          AppTheme.customButton(
            label: 'Move forward',
            onPressed: () =>
                _gameService.movePlayer(widget.gameId, widget.playerId, 'forward'),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (validMoves['canMoveLeft'] == true)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: AppTheme.customButton(
                  label: 'Left',
                  onPressed: () =>
                      _gameService.movePlayer(widget.gameId, widget.playerId, 'left'),
                ),
              ),
            if (validMoves['canMoveRight'] == true)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                child: AppTheme.customButton(
                  label: 'Right',
                  onPressed: () =>
                      _gameService.movePlayer(widget.gameId, widget.playerId, 'right'),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ------------------------------------------------------
  // FONCTION UTILITAIRE
  // ------------------------------------------------------
  bool get hasCardContent {
    return (cardName != null || cardImage != null || descriptionToDisplay != null);
  }

  /// cardDispplay or spacing
  Widget buildCardOrSpacing(Widget body, {double extraSpacing = 0.15}) {
    final screenHeight = MediaQuery.of(context).size.height;

    if (hasCardContent) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          buildCardDisplay(),
          const SizedBox(height: 16),
          body,
        ],
      );
    } else {
      // if no card, put un espace
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: screenHeight * extraSpacing),
          body,
        ],
      );
    }
  }
}
