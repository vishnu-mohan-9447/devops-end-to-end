const express = require('express');
const db = require('../db');
const { authenticate } = require('../middleware/auth');

const router = express.Router();

// GET /api/certificates/me - list logged-in user's certificates
router.get('/me', authenticate, async (req, res) => {
  try {
    const result = await db.query(
      `SELECT cert.*, c.title AS course_title
       FROM certificates cert
       JOIN courses c ON c.id = cert.course_id
       WHERE cert.user_id = $1
       ORDER BY cert.issued_at DESC`,
      [req.user.id]
    );
    res.json(result.rows);
  } catch (err) {
    console.error('List certificates error:', err);
    res.status(500).json({ error: 'Failed to fetch certificates' });
  }
});

module.exports = router;
