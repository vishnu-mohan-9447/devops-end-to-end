const express = require('express');
const db = require('../db');
const { authenticate } = require('../middleware/auth');

const router = express.Router();

// POST /api/enrollments - enroll the logged-in user in a course
router.post('/', authenticate, async (req, res) => {
  try {
    const { courseId } = req.body;
    if (!courseId) {
      return res.status(400).json({ error: 'courseId is required' });
    }

    const result = await db.query(
      `INSERT INTO enrollments (user_id, course_id, status)
       VALUES ($1, $2, 'in_progress')
       ON CONFLICT (user_id, course_id) DO NOTHING
       RETURNING *`,
      [req.user.id, courseId]
    );

    if (result.rows.length === 0) {
      return res.status(200).json({ message: 'Already enrolled in this course' });
    }

    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('Enroll error:', err);
    res.status(500).json({ error: 'Failed to enroll in course' });
  }
});

// GET /api/enrollments/me - list logged-in user's enrollments
router.get('/me', authenticate, async (req, res) => {
  try {
    const result = await db.query(
      `SELECT e.*, c.title, c.description
       FROM enrollments e
       JOIN courses c ON c.id = e.course_id
       WHERE e.user_id = $1
       ORDER BY e.enrolled_at DESC`,
      [req.user.id]
    );
    res.json(result.rows);
  } catch (err) {
    console.error('List enrollments error:', err);
    res.status(500).json({ error: 'Failed to fetch enrollments' });
  }
});

module.exports = router;
