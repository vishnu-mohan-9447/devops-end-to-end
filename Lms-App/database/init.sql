-- ============================================================
-- LMS Data Tier: schema + seed data
-- ============================================================

CREATE TABLE IF NOT EXISTS users (
    id            SERIAL PRIMARY KEY,
    name          VARCHAR(120) NOT NULL,
    email         VARCHAR(160) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role          VARCHAR(20) NOT NULL DEFAULT 'student',
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS courses (
    id          SERIAL PRIMARY KEY,
    title       VARCHAR(200) NOT NULL,
    description TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS modules (
    id          SERIAL PRIMARY KEY,
    course_id   INTEGER NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    title       VARCHAR(200) NOT NULL,
    content     TEXT,
    order_index INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS quizzes (
    id             SERIAL PRIMARY KEY,
    module_id      INTEGER NOT NULL REFERENCES modules(id) ON DELETE CASCADE,
    question       TEXT NOT NULL,
    options        JSONB NOT NULL,
    correct_option INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS enrollments (
    id           SERIAL PRIMARY KEY,
    user_id      INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    course_id    INTEGER NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    status       VARCHAR(20) NOT NULL DEFAULT 'in_progress',
    enrolled_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, course_id)
);

CREATE TABLE IF NOT EXISTS quiz_attempts (
    id              SERIAL PRIMARY KEY,
    user_id         INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    quiz_id         INTEGER NOT NULL REFERENCES quizzes(id) ON DELETE CASCADE,
    selected_option INTEGER NOT NULL,
    is_correct      BOOLEAN NOT NULL,
    attempted_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS certificates (
    id                SERIAL PRIMARY KEY,
    user_id           INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    course_id         INTEGER NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    certificate_code  VARCHAR(40) UNIQUE NOT NULL,
    issued_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, course_id)
);

-- ---------------- seed data ----------------

INSERT INTO courses (title, description) VALUES
    ('Introduction to Cloud Computing', 'Learn the fundamentals of cloud platforms, virtualization, and core services.'),
    ('DevOps Foundations', 'Understand CI/CD, containers, and infrastructure as code.')
ON CONFLICT DO NOTHING;

INSERT INTO modules (course_id, title, content, order_index) VALUES
    (1, 'What is Cloud Computing?', 'Cloud computing delivers on-demand IT resources over the internet.', 1),
    (1, 'Service Models', 'IaaS, PaaS and SaaS explained with real world examples.', 2),
    (2, 'What is CI/CD?', 'Continuous integration and continuous delivery automate the software release process.', 1)
ON CONFLICT DO NOTHING;

INSERT INTO quizzes (module_id, question, options, correct_option) VALUES
    (1, 'Cloud computing delivers resources over which medium?', '["Local network only", "The internet", "A CD-ROM", "Fax machine"]', 1),
    (2, 'Which of these is a PaaS example?', '["AWS EC2", "Heroku", "A physical server", "A USB drive"]', 1),
    (3, 'What does CI stand for?', '["Continuous Integration", "Cloud Instance", "Code Inspection", "Container Image"]', 0)
ON CONFLICT DO NOTHING;
