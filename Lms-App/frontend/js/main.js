function renderNav() {
  const user = getUser();
  const nav = document.getElementById('nav-links');
  if (!nav) return;

  if (user) {
    nav.innerHTML = `
      <a href="index.html">Courses</a>
      <a href="dashboard.html">Dashboard</a>
      <a href="#" id="logout-link">Logout (${user.name})</a>
    `;
    document.getElementById('logout-link').addEventListener('click', (e) => {
      e.preventDefault();
      clearToken();
      window.location.href = 'login.html';
    });
  } else {
    nav.innerHTML = `
      <a href="index.html">Courses</a>
      <a href="login.html">Login</a>
      <a href="register.html">Register</a>
    `;
  }
}

function requireAuth() {
  if (!getToken()) {
    window.location.href = 'login.html';
  }
}

document.addEventListener('DOMContentLoaded', renderNav);
