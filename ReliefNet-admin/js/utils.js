// ─── ICON MAP ───────────────────────────────────────────────
export function typeIcon(type) {
  const icons = { Medical: '🏥', Shelter: '🏠', Food: '🍱', Other: '⚠️' };
  return icons[type] || '⚠️';
}

// ─── BADGES ─────────────────────────────────────────────────
export function urgencyBadge(u) {
  if (!u) return '—';
  const cls = u === 'High' ? 'badge-high' : u === 'Medium' ? 'badge-medium' : 'badge-low';
  const dot = u === 'High' ? '#EF4444' : u === 'Medium' ? '#F97316' : '#22C55E';
  return `<span class="badge ${cls}"><span class="stat-dot" style="background:${dot}"></span>${u}</span>`;
}

export function statusBadge(s) {
  if (!s) return '—';
  const cls = s === 'completed' ? 'badge-completed' : s === 'in_progress' ? 'badge-in_progress' : 'badge-active';
  return `<span class="badge ${cls}">${s}</span>`;
}

export function appStatusBadge(s) {
  const cls = s === 'approved' ? 'badge-approved' : s === 'rejected' ? 'badge-rejected' : 'badge-pending';
  return `<span class="badge ${cls}">${s || 'pending'}</span>`;
}

// ─── TIME FORMAT ─────────────────────────────────────────────
export function formatTime(ts) {
  if (!ts) return '—';
  const d = ts.toDate ? ts.toDate() : new Date(ts);
  return d.toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' });
}

// ─── TOAST ──────────────────────────────────────────────────
export function showToast(msg) {
  const t = document.getElementById('toast');
  t.textContent = msg;
  t.style.display = 'block';
  setTimeout(() => { t.style.display = 'none'; }, 3000);
}

// ─── LOADING / EMPTY STATES ──────────────────────────────────
export function loadingRow(cols) {
  return `<tr><td colspan="${cols}" class="loading"><span class="spinner"></span>Loading...</td></tr>`;
}

export function emptyRow(cols, icon, text) {
  return `<tr><td colspan="${cols}"><div class="empty"><div class="empty-icon">${icon}</div><div class="empty-text">${text}</div></div></td></tr>`;
}

// ─── PAGE NAV ────────────────────────────────────────────────
window.showPage = (page) => {
  document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
  document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
  document.getElementById('page-' + page).classList.add('active');
  event.currentTarget.classList.add('active');
};
