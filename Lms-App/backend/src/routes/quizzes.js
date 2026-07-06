const express = require('express');
const { v4: uuidv4 } = require('uuid');
const db = require('../db');
const { authenticate } = require('../middleware/auth');

const router = express.Router();

// POST /api/quizzes/:quizId/submit - submit an answer and score it
router.post('/:quizId/submit', authenticate, async (req, res) => {
  try {
    const { quizId } = req.params;
    const { selectedOption } = req.body;

    if (selectedOption === undefined) {
      return res.status(400).json({ error: 'selectedOption is required' });
    }

    const quizResult = await db.query('SELECT * FROM quizzes WHERE id = $1', [quizId]);
    if (quizResult.rows.length === 0) {
      return res.status(404).json({ error: 'Quiz not found' });
    }

    const quiz = quizResult.rows[0];
    const isCorrect = quiz.correct_option === selectedOption;

    await db.query(
      `INSERT INTO quiz_attempts (user_id, quiz_id, selected_option, is_correct)
       VALUES ($1, $2, $3, $4)`,
      [req.user.id, quizId, selectedOption, isCorrect]
    );

    // Business rule: check if this completes the course, issue certificate if so
    const certificate = await maybeIssueCertificate(req.user.id, quiz.module_id);

    res.json({ isCorrect, correctOption: quiz.correct_option, certificateIssued: !!certificate });
  } catch (err) {
    console.error('Submit quiz error:', err);
    res.status(500).json({ error: 'Failed to submit quiz answer' });
  }
});

// Core application-tier business logic: award a certificate once every
// quiz in a course has been answered correctly by the user at least once.
async function maybeIssueCertificate(userId, moduleId) {
  const courseRes = await db.query('SELECT course_id FROM modules WHERE id = $1', [moduleId]);
  if (courseRes.rows.length === 0) return null;
  const courseId = courseRes.rows[0].course_id;

  const totalQuizzes = await db.query(
    `SELECT COUNT(*)::int AS count FROM quizzes q
     JOIN modules m ON m.id = q.module_id
     WHERE m.course_id = $1`,
    [courseId]
  );

  const correctlyAnswered = await db.query(
    `SELECT COUNT(DISTINCT qa.quiz_id)::int AS count
     FROM quiz_attempts qa
     JOIN quizzes q ON q.id = qa.quiz_id
     JOIN modules m ON m.id = q.module_id
     WHERE m.course_id = $1 AND qa.user_id = $2 AND qa.is_correct = true`,
    [courseId, userId]
  );

  if (
    totalQuizzes.rows[0].count > 0 &&
    totalQuizzes.rows[0].count === correctlyAnswered.rows[0].count
  ) {
    const certResult = await db.query(
      `INSERT INTO certificates (user_id, course_id, certificate_code)
       VALUES ($1, $2, $3)
       ON CONFLICT (user_id, course_id) DO NOTHING
       RETURNING *`,
      [userId, courseId, `CERT-${uuidv4().slice(0, 8).toUpperCase()}`]
    );

    await db.query(
      `UPDATE enrollments SET status = 'completed' WHERE user_id = $1 AND course_id = $2`,
      [userId, courseId]
    );

    return certResult.rows[0] || true;
  }

  return null;
}

module.exports = router;
