// ─── ICON MAP ───────────────────────────────────────────────
export function typeIcon(type) {
  const icons = { Medical: '🏥', Shelter: '🏠', Food: '🍱', Other: '⚠️' };
  return icons[type] || '⚠️';
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
window.showPage = (page, el) => {
  document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
  document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
  document.getElementById('page-' + page).classList.add('active');
  if (el) el.classList.add('active');
  // Close sidebar on mobile after navigation
  if (window.innerWidth <= 768) closeSidebar();
};

// ─── DASHBOARD REDIRECTS ────────────────────────────────────
window.goToReports = (filter) => {
  const navBtn = document.querySelector(`.sidebar-nav button[onclick*="'reports'"]`);
  window.showPage('reports', navBtn);
  const filterBtn = document.querySelector(`#page-reports .filter-btn[onclick*="'${filter}'"]`);
  if (filterBtn) {
    filterBtn.click();
  }
};

window.goToApps = (filter) => {
  const navBtn = document.querySelector(`.sidebar-nav button[onclick*="'applications'"]`);
  window.showPage('applications', navBtn);
  const filterBtn = document.querySelector(`#page-applications .filter-btn[onclick*="'${filter}'"]`);
  if (filterBtn) {
    filterBtn.click();
  }
};


// ─── MOBILE SIDEBAR TOGGLE ──────────────────────────────────
function closeSidebar() {
  document.getElementById('sidebar').classList.remove('open');
  document.getElementById('sidebar-overlay').classList.remove('open');
  document.getElementById('hamburger-btn').classList.remove('active');
}

window.toggleSidebar = () => {
  const sidebar = document.getElementById('sidebar');
  const overlay = document.getElementById('sidebar-overlay');
  const btn = document.getElementById('hamburger-btn');
  sidebar.classList.toggle('open');
  overlay.classList.toggle('open');
  btn.classList.toggle('active');
};

// ─── THEME TOGGLE ───────────────────────────────────────────
window.toggleTheme = () => {
  const isDark = document.documentElement.classList.toggle('dark-mode');
  localStorage.setItem('theme', isDark ? 'dark' : 'light');
  updateThemeUI();
};

export function updateThemeUI() {
  const isDark = document.documentElement.classList.contains('dark-mode');
  document.querySelectorAll('.theme-icon').forEach(icon => {
    icon.textContent = isDark ? '☀️' : '🌙';
  });
  document.querySelectorAll('.theme-text').forEach(text => {
    text.textContent = isDark ? 'Light Mode' : 'Dark Mode';
  });
  
  // Re-render overview if active to refresh Chart.js theme colors
  const pageOverview = document.getElementById('page-overview');
  if (pageOverview && pageOverview.classList.contains('active')) {
    import('./overview.js').then(m => m.renderOverview());
  }
}

export function initTheme() {
  const theme = localStorage.getItem('theme');
  const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
  if (theme === 'dark' || (!theme && prefersDark)) {
    document.documentElement.classList.add('dark-mode');
  } else {
    document.documentElement.classList.remove('dark-mode');
  }
  updateThemeUI();
}

// Initialize theme immediately
initTheme();

// ─── PAGINATION HELPER ──────────────────────────────────────
export function renderPagination(containerId, currentPage, totalPages, onPrevStr, onNextStr) {
  const container = document.getElementById(containerId);
  if (!container) return;

  if (totalPages <= 1) {
    container.innerHTML = '';
    container.style.display = 'none';
    return;
  }
  container.style.display = 'flex';
  container.innerHTML = `
    <button class="pagination-btn" ${currentPage === 1 ? 'disabled' : ''} onclick="${onPrevStr}">⟨ Prev</button>
    <span class="pagination-info">Page ${currentPage} of ${totalPages}</span>
    <button class="pagination-btn" ${currentPage === totalPages ? 'disabled' : ''} onclick="${onNextStr}">Next ⟩</button>
  `;
}

// ─── CSV EXPORT HELPER ──────────────────────────────────────
export function exportToCSV(filename, headers, rows) {
  const csvContent = [
    headers.join(','),
    ...rows.map(row => row.map(val => {
      const cleanVal = String(val ?? '').replace(/"/g, '""');
      return `"${cleanVal}"`;
    }).join(','))
  ].join('\n');

  const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
  const link = document.createElement('a');
  if (link.download !== undefined) {
    const url = URL.createObjectURL(blob);
    link.setAttribute('href', url);
    link.setAttribute('download', filename);
    link.style.visibility = 'hidden';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  }
}

// ─── AUDIT LOGGING ──────────────────────────────────────────
import { auth, db } from "./firebase-init.js";
import { collection, addDoc, serverTimestamp } from "https://www.gstatic.com/firebasejs/10.12.0/firebase-firestore.js";

export async function logAdminAction(actionType, targetId, details = {}) {
  const user = auth.currentUser;
  if (!user) return;
  try {
    await addDoc(collection(db, 'admin_actions'), {
      adminUid: user.uid,
      adminEmail: user.email,
      action: actionType,
      targetId: targetId,
      details: details,
      timestamp: serverTimestamp()
    });
  } catch (err) {
    console.error("Failed to write audit log:", err);
  }
}

// ─── FORCE MANUAL SYNC ──────────────────────────────────────
window.forceSync = async () => {
  const btns = document.querySelectorAll('.sync-btn');
  btns.forEach(btn => btn.classList.add('spinning'));
  showToast('🔄 Syncing data in real-time...');
  try {
    const reportsM = await import('./reports.js');
    const appsM = await import('./applications.js');
    const volunteersM = await import('./volunteers.js');
    await Promise.all([
      reportsM.loadReports(),
      appsM.loadApplications(),
      volunteersM.loadVolunteers()
    ]);
    showToast('✅ Data synchronized');
  } catch (e) {
    showToast('❌ Sync failed: ' + e.message);
  } finally {
    btns.forEach(btn => btn.classList.remove('spinning'));
  }
};
