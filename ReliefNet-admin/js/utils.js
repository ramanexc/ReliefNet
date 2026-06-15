// ─── ICON MAP (Command Center Set) ─────────────────────────
export function typeIcon(type) {
  const icons = {
    'Food Assistance': `<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5"></path></svg>`,
    'Medical Assistance': `<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M22 12h-4l-3 9L9 3l-3 9H2"></path></svg>`,
    'Shelter Assistance': `<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"></path><polyline points="9 22 9 12 15 12 15 22"></polyline></svg>`,
    'Water & Sanitation': `<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M7 16.3c2.2 0 4-1.8 4-4 0-3.3-4-6.3-4-6.3S3 9 3 12.3c0 2.2 1.8 4 4 4z"></path></svg>`,
    'Rescue Required': `<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"></path></svg>`,
    'Utilities & Infrastructure': `<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.7a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.7z"></path></svg>`,
    'Other': `<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="8" x2="12" y2="12"></line><line x1="12" y1="16" x2="12.01" y2="16"></line></svg>`
  };
  return icons[type] || icons.Other;
}

// ─── SANITIZE ───────────────────────────────────────────────
export function esc(str) {
  if (!str) return '—';
  const div = document.createElement('div');
  div.textContent = String(str);
  return div.innerHTML;
}

// ─── BADGES ─────────────────────────────────────────────────
export function urgencyBadge(u) {
  if (!u) return '—';
  const cls = u === 'High' ? 'badge-critical' : u === 'Medium' ? 'badge-warning' : 'badge-info';
  return `<span class="badge-pill ${cls}">${u}</span>`;
}

export function statusBadge(s) {
  if (!s) return '—';
  let cls = 'badge-info';
  if (s === 'completed') cls = 'badge-success';
  else if (s === 'in_progress') cls = 'badge-warning';
  else if (s === 'suspected_spam' || s === 'flagged') cls = 'badge-critical';
  const label = s.replace('_', ' ');
  return `<span class="badge-pill ${cls}">${label}</span>`;
}

export function appStatusBadge(s) {
  const cls = s === 'approved' ? 'badge-success' : s === 'rejected' ? 'badge-critical' : 'badge-warning';
  return `<span class="badge-pill ${cls}">${s || 'pending'}</span>`;
}

// ─── TIME FORMAT ─────────────────────────────────────────────
export function formatTime(ts) {
  if (!ts) return '—';
  const d = ts.toDate ? ts.toDate() : new Date(ts);
  return d.toLocaleString('en-IN', {
    day: 'numeric', month: 'short', year: 'numeric',
    hour: '2-digit', minute: '2-digit', second: '2-digit'
  });
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
  return `<tr><td colspan="${cols}" class="loading"><span class="spinner"></span>Initalizing Feed...</td></tr>`;
}

export function emptyRow(cols, icon, text) {
  return `<tr><td colspan="${cols}"><div class="empty"><div class="empty-text" style="font-weight:600; color:var(--secondary); text-transform:uppercase; letter-spacing:0.05em;">NO DATA DETECTED</div></div></td></tr>`;
}

// ─── PAGE NAV ────────────────────────────────────────────────
window.showPage = (page, el) => {
  document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
  document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));

  // Specific override for reports-list/hub link
  const pageId = page === 'reports-hub' ? 'reports-list' : page;
  const pageEl = document.getElementById('page-' + pageId);
  if (pageEl) pageEl.classList.add('active');
  if (el) el.classList.add('active');

  if (window.innerWidth <= 768) toggleSidebar();

  if (page === 'broadcasts') import('./broadcasts.js').then(m => m.loadBroadcasts());
  if (page === 'overview') import('./overview.js').then(m => m.invalidateOverviewMap());
};

// ─── DASHBOARD REDIRECTS ────────────────────────────────────
window.goToReports = (filter) => {
  const navBtn = document.querySelector(`.sidebar-nav button[onclick*="'reports-list'"]`);
  window.openReportsView(filter === 'all' ? 'all' : filter === 'completed' ? 'resolved' : filter);
  if (navBtn) {
    document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
    navBtn.classList.add('active');
  }
};

window.goToApps = (filter) => {
  const navBtn = document.querySelector(`.sidebar-nav button[onclick*="'applications'"]`);
  window.showPage('applications', navBtn);
  const filterBtn = document.querySelector(`#page-applications .filter-btn[onclick*="'${filter}'"]`);
  if (filterBtn) filterBtn.click();
};

window.toggleSidebar = () => {
  const sb = document.getElementById('sidebar');
  sb.classList.toggle('open');
};

window.toggleTheme = () => {
  const isDark = document.documentElement.classList.toggle('dark-mode');
  localStorage.setItem('theme', isDark ? 'dark' : 'light');
  updateThemeUI(isDark);

  // Re-render components that depend on theme variables (like charts and maps)
  const pageOverview = document.getElementById('page-overview');
  if (pageOverview && pageOverview.classList.contains('active')) {
    import('./overview.js').then(m => m.renderOverview());
  }
};

const moonIcon = `<svg class="icon" viewBox="0 0 24 24"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"></path></svg>`;
const sunIcon = `<svg class="icon" viewBox="0 0 24 24"><circle cx="12" cy="12" r="5"></circle><line x1="12" y1="1" x2="12" y2="3"></line><line x1="12" y1="21" x2="12" y2="23"></line><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"></line><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"></line><line x1="1" y1="12" x2="3" y2="12"></line><line x1="21" y1="12" x2="23" y2="12"></line><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"></line><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"></line></svg>`;

function updateThemeUI(isDark) {
  const iconEl = document.getElementById('theme-toggle-icon');
  const textEl = document.getElementById('theme-toggle-text');
  if (iconEl) iconEl.innerHTML = isDark ? sunIcon : moonIcon;
  if (textEl) textEl.textContent = isDark ? 'Light Mode' : 'Dark Mode';
}

export function initTheme() {
  const theme = localStorage.getItem('theme');
  const isDark = theme === 'dark';
  if (isDark) {
    document.documentElement.classList.add('dark-mode');
  } else {
    document.documentElement.classList.remove('dark-mode');
  }
  updateThemeUI(isDark);
}

// Initialize theme immediately
initTheme();

export function renderPagination(containerId, currentPage, totalPages, onPrevStr, onNextStr) {
  const container = document.getElementById(containerId);
  if (!container || totalPages <= 1) {
    if(container) container.style.display = 'none';
    return;
  }
  container.style.display = 'flex';
  container.innerHTML = `
    <button class="pagination-btn" ${currentPage === 1 ? 'disabled' : ''} onclick="${onPrevStr}">PREV</button>
    <span class="pagination-info">REGION ${currentPage} / ${totalPages}</span>
    <button class="pagination-btn" ${currentPage === totalPages ? 'disabled' : ''} onclick="${onNextStr}">NEXT</button>
  `;
}

export function exportToCSV(filename, headers, rows) {
  const csvContent = [headers.join(','), ...rows.map(row => row.map(val => `"${String(val ?? '').replace(/"/g, '""')}"`).join(','))].join('\n');
  const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
  const link = document.createElement('a');
  link.href = URL.createObjectURL(blob);
  link.download = filename;
  link.click();
}

import { auth, db } from "./firebase-init.js";
import { collection, addDoc, serverTimestamp } from "https://www.gstatic.com/firebasejs/10.12.0/firebase-firestore.js";

export async function logAdminAction(actionType, targetId, details = {}) {
  const user = auth.currentUser;
  if (!user) return;
  try {
    await addDoc(collection(db, 'admin_actions'), {
      adminUid: user.uid, adminEmail: user.email,
      action: actionType, targetId: targetId,
      details: details, timestamp: serverTimestamp()
    });
  } catch (err) { console.error(err); }
}

window.forceSync = async () => {
  showToast('Establishing fresh sync...');
  try {
    const [r, a, v] = await Promise.all([import('./reports.js'), import('./applications.js'), import('./volunteers.js')]);
    await Promise.all([r.loadReports(), a.loadApplications(), v.loadVolunteers()]);
    showToast('Data stream synchronized');
  } catch (e) { showToast('Sync error: ' + e.message); }
};

window.togglePasswordVisibility = () => {
  const passInput = document.getElementById('pass-input');
  const eyeIcon = document.getElementById('eye-icon');
  if (!passInput || !eyeIcon) return;

  if (passInput.type === 'password') {
    passInput.type = 'text';
    eyeIcon.innerHTML = `<path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24"></path><line x1="1" y1="1" x2="23" y2="23"></line>`;
  } else {
    passInput.type = 'password';
    eyeIcon.innerHTML = `<path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"></path><circle cx="12" cy="12" r="3"></circle>`;
  }
};
