// game/cardHandlers/quizCardHandler.js

const redisClient = require('../../config/redis');
const GenericCardHandler = require('./genericCardHandler');
const quizModel = require('../../models/quiz');

class QuizCardHandler extends GenericCardHandler {
  constructor(gameId, io) {
    super(gameId, io);
  }

  async handleCard(playerId, card) {
    await super.handleCard(playerId, card);

    console.log(`QuizCardHandler: Quiz card drawn. Waiting for 'startQuiz'...`);
    // Ici, on ne commence pas le quiz tout de suite. 
    // On attend l'événement socket "startQuiz" que le front enverra
    // lorsque le joueur aura cliqué sur un thème.
  }

  /**
   * startQuiz : appelé lorsqu'on reçoit l'événement 'startQuiz'
   *   - On va chercher 3 questions dans la DB pour le thème choisi
   *   - On stocke tout ça + le "reward pattern" dans quizState
   *   - On émet un événement 'quizStarted' et on enchaîne la première question
   */
  async startQuiz(playerId, chosenTheme) {
    try {
      // 1) On récupère la carte courante
      const cardJson = await redisClient.hGet(`game:${this.gameId}`, 'currentCard');
      const currentCard = JSON.parse(cardJson || '{}');

      // 2) On récupère le reward pattern (ex. "1b;2b;3b") et on le parse
      const cardRewardString = currentCard.card_reward || '1b;2b;3b';
      const rewardPattern = cardRewardString.split(';').map(r => parseInt(r.replace('b', ''), 10));
      // ex: [1, 2, 3]

      // 3) On passe le turnState à "quizInProgress"
      await redisClient.hSet(`game:${this.gameId}`, 'turnState', 'quizInProgress');

      // 4) Récupérer 3 questions pour le thème choisi
      //    (on suppose un helper quizModel.getThreeQuestions(chosenTheme))
      const questions = await quizModel.getThreeQuestions(chosenTheme);

      // 5) Créer l'état "quizState" et le stocker
      const quizState = {
        questions,           // liste de 3 questions
        currentQuestion: 0,  // index sur la question courante
        correctAnswers: 0,
        earnedBerries: 0,
        rewardPattern,       // ex: [1, 2, 3]
        chosenTheme,         // "Explorers history" ou "Exotic Nature"
      };
      await redisClient.hSet(`game:${this.gameId}`, 'quizState', JSON.stringify(quizState));

      // 6) Émettre un événement "quizStarted" => 
      //    le front saura qu'on a choisi <chosenTheme> et qu'on démarre 
      this.io.to(this.gameId).emit('quizStarted', {
        chosenTheme,
      });

      // 7) Envoyer la première question
      await this.sendNextQuestion();
    } catch (error) {
      console.error('QuizCardHandler: Error starting quiz:', error);
    }
  }

  async sendNextQuestion() {
    try {
      const quizStateJson = await redisClient.hGet(`game:${this.gameId}`, 'quizState');
      const quizState = JSON.parse(quizStateJson || '{}');

      // Si on a fini les questions => endQuiz
      if (quizState.currentQuestion >= quizState.questions.length) {
        console.log('QuizCardHandler: All questions answered. Ending quiz.');
        await this.endQuiz();
        return;
      }

      // On récupère la question en cours
      const question = quizState.questions[quizState.currentQuestion];

      // On envoie un événement "quizQuestion" 
      // => front l'affiche (avec timer 8s, etc.)
      this.io.to(this.gameId).emit('quizQuestion', {
        questionIndex: quizState.currentQuestion,
        questionId: question.question_id,
        questionDescription: question.question_description,
        questionOptions: JSON.parse(question.question_options), 
        questionDifficulty: question.question_difficulty,
      });

      console.log(`QuizCardHandler: Sending question #${quizState.currentQuestion + 1} in theme "${quizState.chosenTheme}"`);
    } catch (error) {
      console.error('QuizCardHandler: Error sending next question:', error);
    }
  }

  /**
   * handleAnswer : quand le joueur actif répond
   */
  async handleAnswer(playerId, givenAnswer) {
    try {
      const quizStateJson = await redisClient.hGet(`game:${this.gameId}`, 'quizState');
      const quizState = JSON.parse(quizStateJson || '{}');

      const currentQIndex = quizState.currentQuestion;
      const question = quizState.questions[currentQIndex];
      if (!question) {
        console.log('QuizCardHandler: No question found => maybe quiz ended?');
        return;
      }

      const isCorrect = (givenAnswer === question.question_answer);

      // Si la réponse est correcte, on incrémente correctAnswers
      // et on ajoute la récompense associée à CE rang de question
      // (ex: rewardPattern[0] si c'est la 1ère question).
      if (isCorrect) {
        quizState.correctAnswers += 1;
        // Au lieu d’utiliser la difficulty, on utilise rewardPattern
        const questionReward = quizState.rewardPattern[currentQIndex] || 0;
        quizState.earnedBerries += questionReward;
      }

      // On stocke l'état mis à jour
      await redisClient.hSet(`game:${this.gameId}`, 'quizState', JSON.stringify(quizState));

      // On émet "quizAnswerResult"
      this.io.to(this.gameId).emit('quizAnswerResult', {
        questionIndex: currentQIndex,
        correctAnswer: question.question_answer,
        givenAnswer,
        isCorrect,
      });

      console.log(`QuizCardHandler: Player ${playerId} => correct? ${isCorrect}`);

      // Passer à la question suivante après 1s
      quizState.currentQuestion += 1;
      await redisClient.hSet(`game:${this.gameId}`, 'quizState', JSON.stringify(quizState));

      setTimeout(() => {
        this.sendNextQuestion();
      }, 1000);

    } catch (error) {
      console.error('QuizCardHandler: Error handling quiz answer:', error);
    }
  }

  async endQuiz() {
    try {
      console.log('QuizCardHandler: Ending quiz...');
      const quizStateJson = await redisClient.hGet(`game:${this.gameId}`, 'quizState');
      const quizState = JSON.parse(quizStateJson || '{}');

      await redisClient.hSet(`game:${this.gameId}`, 'turnState', 'quizResult');

      // Mise à jour du joueur actif dans Redis
      const gameData = await redisClient.hGetAll(`game:${this.gameId}`);
      const players = JSON.parse(gameData.players || '[]');
      const activePlayer = players.find((p) => p.playerId === gameData.activePlayerId);

      if (activePlayer) {
        // Ajout de l'ensemble des berries gagnés
        activePlayer.berries = (activePlayer.berries || 0) + quizState.earnedBerries;
        await redisClient.hSet(`game:${this.gameId}`, 'players', JSON.stringify(players));

        console.log(`QuizCardHandler: ${activePlayer.playerName} earned ${quizState.earnedBerries} berries.`);
      }

      // Émettre "quizEnd" => front affichera le récap final + bouton "End the turn"
      this.io.to(this.gameId).emit('quizEnd', {
        correctAnswers: quizState.correctAnswers,
        totalQuestions: quizState.questions.length,
        earnedBerries: quizState.earnedBerries,
      });

    } catch (error) {
      console.error('QuizCardHandler: Error ending quiz:', error);
    }
  }
}

module.exports = QuizCardHandler;
