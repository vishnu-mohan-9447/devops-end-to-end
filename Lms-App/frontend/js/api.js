// API_BASE is resolved at page-load time so the same static bundle
// works in Docker Compose (dev) and Kubernetes (prod) without a rebuild.
// It expects the backend to be reachable at /api via reverse proxy,
// or falls back to a direct host:port for local development.
const API_BASE = window.LMS_API_BASE || '/api';

function getToken() {
  return sessionStorage.getItem('lms_token');
}

function setToken(token) {
  sessionStorage.setItem('lms_token', token);
}

function clearToken() {
  sessionStorage.removeItem('lms_token');
  sessionStorage.removeItem('lms_user');
}

function getUser() {
  const raw = sessionStorage.getItem('lms_user');
  return raw ? JSON.parse(raw) : null;
}

function setUser(user) {
  sessionStorage.setItem('lms_user', JSON.stringify(user));
}

async function apiRequest(path, options = {}) {
  const headers = { 'Content-Type': 'application/json', ...(options.headers || {}) };
  const token = getToken();
  if (token) headers['Authorization'] = `Bearer ${token}`;

  const res = await fetch(`${API_BASE}${path}`, { ...options, headers });
  const data = await res.json().catch(() => ({}));

  if (!res.ok) {
    throw new Error(data.error || `Request failed with status ${res.status}`);
  }
  return data;
}

const api = {
  register: (name, email, password) =>
    apiRequest('/auth/register', { method: 'POST', body: JSON.stringify({ name, email, password }) }),

  login: (email, password) =>
    apiRequest('/auth/login', { method: 'POST', body: JSON.stringify({ email, password }) }),

  listCourses: () => apiRequest('/courses'),

  getCourse: (id) => apiRequest(`/courses/${id}`),

  getModuleQuiz: (moduleId) => apiRequest(`/courses/modules/${moduleId}/quiz`),

  enroll: (courseId) => apiRequest('/enrollments', { method: 'POST', body: JSON.stringify({ courseId }) }),

  myEnrollments: () => apiRequest('/enrollments/me'),

  submitQuiz: (quizId, selectedOption) =>
    apiRequest(`/quizzes/${quizId}/submit`, { method: 'POST', body: JSON.stringify({ selectedOption }) }),

  myCertificates: () => apiRequest('/certificates/me'),
};
