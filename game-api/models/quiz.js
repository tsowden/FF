    // models/quiz.js
    const db = require('../config/db'); // le pool MySQL2/promise

    /**
     * getThreeQuestions:
     *   Récupère 3 questions pour un certain thème :
     *    1 question difficulty=1
     *    1 question difficulty=2
     *    1 question difficulty=3
     */
    async function getThreeQuestions(category) {
    const questions = [];

    // 1) difficulty=1
    const [rows1] = await db.query(
        `SELECT * FROM questions
        WHERE question_category = ?
        AND question_difficulty = 1
        ORDER BY RAND()
        LIMIT 1`,
        [category]
    );
    // rows1 est un array de lignes
    if (rows1 && rows1.length > 0) {
        questions.push(rows1[0]);
    }

    // 2) difficulty=2
    const [rows2] = await db.query(
        `SELECT * FROM questions
        WHERE question_category = ?
        AND question_difficulty = 2
        ORDER BY RAND()
        LIMIT 1`,
        [category]
    );
    if (rows2 && rows2.length > 0) {
        questions.push(rows2[0]);
    }

    // 3) difficulty=3
    const [rows3] = await db.query(
        `SELECT * FROM questions
        WHERE question_category = ?
        AND question_difficulty = 3
        ORDER BY RAND()
        LIMIT 1`,
        [category]
    );
    if (rows3 && rows3.length > 0) {
        questions.push(rows3[0]);
    }

    return questions;
    }

    module.exports = {
    getThreeQuestions,
    };