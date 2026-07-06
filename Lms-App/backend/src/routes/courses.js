const express = require('express');
const db = require('../db');

const router = express.Router();

// GET /api/courses - list all courses
router.get('/', async (req, res) => {
  try {
    const result = await db.query('SELECT * FROM courses ORDER BY id');
    res.json(result.rows);
  } catch (err) {
    console.error('List courses error:', err);
    res.status(500).json({ error: 'Failed to fetch courses' });
  }
});

// GET /api/courses/:id - course detail with modules
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const course = await db.query('SELECT * FROM courses WHERE id = $1', [id]);
    if (course.rows.length === 0) {
      return res.status(404).json({ error: 'Course not found' });
    }

    const modules = await db.query(
      'SELECT * FROM modules WHERE course_id = $1 ORDER BY order_index',
      [id]
    );

    res.json({ ...course.rows[0], modules: modules.rows });
  } catch (err) {
    console.error('Get course error:', err);
    res.status(500).json({ error: 'Failed to fetch course' });
  }
});

// GET /api/courses/modules/:moduleId/quiz - quiz for a module
router.get('/modules/:moduleId/quiz', async (req, res) => {
  try {
    const { moduleId } = req.params;
    const result = await db.query(
      'SELECT id, module_id, question, options FROM quizzes WHERE module_id = $1',
      [moduleId]
    );
    res.json(result.rows);
  } catch (err) {
    console.error('Get quiz error:', err);
    res.status(500).json({ error: 'Failed to fetch quiz' });
  }
});

module.exports = router;
