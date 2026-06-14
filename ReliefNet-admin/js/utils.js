// ─── ICON MAP ───────────────────────────────────────────────
export function typeIcon(type) {
  const icons = {
    'Medical Assistance': `<svg class="icon icon-medical" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" style="color:#EF4444;"><path d="M22 12h-4l-3 9L9 3l-3 9H2"></path></svg>`,
    'Food Assistance': `<svg class="icon icon-food" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" style="color:#F97316;"><path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5"></path></svg>`,
    'Shelter Assistance': `<svg class="icon icon-shelter" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" style="color:#2563EB;"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"></path><polyline points="9 22 9 12 15 12 15 22"></polyline></svg>`,
    'Water & Sanitation': `<svg class="icon icon-water" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" style="color:#06B6D4;"><path d="M7 16.3c2.2 0 4-1.8 4-4 0-3.3-4-6.3-4-6.3S3 9 3 12.3c0 2.2 1.8 4 4 4z"></path><path d="M17 16.3c2.2 0 4-1.8 4-4 0-3.3-4-6.3-4-6.3s-4 3-4 6.3c0 2.2 1.8 4 4 4z"></path></svg>`,
    'Rescue Required': `<svg class="icon icon-rescue" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" style="color:#F87171;"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"></path></svg>`,
    'Utilities & Infrastructure': `<svg class="icon icon-infra" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" style="color:#FBBF24;"><path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.7a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.7z"></path></svg>`,
    'Other': `<svg class="icon icon-other" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" style="color:#6B7280;"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="8" x2="12" y2="12"></line><line x1="12" y1="16" x2="12.01" y2="16"></line></svg>`,
    // Aliases for backward compatibility
    'Medical': `<svg class="icon icon-medical" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" style="color:#EF4444;"><path d="M22 12h-4l-3 9L9 3l-3 9H2"></path></svg>`,
    'Food': `<svg class="icon icon-food" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" style="color:#F97316;"><path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5"></path></svg>`,
    'Shelter': `<svg class="icon icon-shelter" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" style="color:#2563EB;"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"></path><polyline points="9 22 9 12 15 12 15 22"></polyline></svg>`,
    'Water': `<svg class="icon icon-water" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" style="color:#06B6D4;"><path d="M7 16.3c2.2 0 4-1.8 4-4 0-3.3-4-6.3-4-6.3S3 9 3 12.3c0 2.2 1.8 4 4 4z"></path><path d="M17 16.3c2.2 0 4-1.8 4-4 0-3.3-4-6.3-4-6.3s-4 3-4 6.3c0 2.2 1.8 4 4 4z"></path></svg>`,
    'Fire': `<svg class="icon icon-fire" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" style="color:#F97316;"><path d="M12 2c1 2 2 3.5 1 5.5-.8 2-2 2.5-2 4.5 0 2 1.5 4 4 4 2 0 3.5-1.5 3.5-4 0-2.5-2-4.5-4-5.5 0 2-1.5 3-1.5 5 0 1 1 2 2 2s2-1 2-2.5c0-1.5-1-2.5-3-5z"></path></svg>`
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
  const cls = u === 'High' ? 'badge-high' : u === 'Medium' ? 'badge-medium' : 'badge-low';
  const dot = u === 'High' ? '#EF4444' : u === 'Medium' ? '#F97316' : '#22C55E';
  return `<span class="badge ${cls}"><span class="stat-dot" style="background:${dot}"></span>${u}</span>`;
}

export function statusBadge(s) {
  if (!s) return '—';
  let cls = 'badge-active';
  if (s === 'completed') cls = 'badge-completed';
  else if (s === 'in_progress') cls = 'badge-in_progress';
  else if (s === 'suspected_spam' || s === 'flagged') cls = 'badge-red';
  else if (s === 'verified') cls = 'badge-green';

  const label = s.replace('_', ' ');
  return `<span class="badge ${cls}">${label}</span>`;
}

export function appStatusBadge(s) {
  const cls = s === 'approved' ? 'badge-approved' : s === 'rejected' ? 'badge-rejected' : 'badge-pending';
  return `<span class="badge ${cls}">${s || 'pending'}</span>`;
}

// ─── TIME FORMAT ─────────────────────────────────────────────
export function formatTime(ts) {
  if (!ts) return '—';
  const d = ts.toDate ? ts.toDate() : new Date(ts);
  return d.toLocaleString('en-IN', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: true
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
  return `<tr><td colspan="${cols}" class="loading"><span class="spinner"></span>Loading...</td></tr>`;
}

export function emptyRow(cols, icon, text) {
  let iconHtml = icon;
  if (icon === '📭' || icon === 'empty') {
    iconHtml = `<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" style="width:36px;height:36px;color:var(--gray-400);"><path d="M22 13h-4l-2 4H8l-2-4H2"></path><path d="M5.4 20h13.2c1 0 1.9-.8 2-1.8L22 9H2l1.4 9.2c.1 1 .9 1.8 1.8 1.8z"></path></svg>`;
  } else if (icon === '👥' || icon === 'users') {
    iconHtml = `<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" style="width:36px;height:36px;color:var(--gray-400);"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path><circle cx="9" cy="7" r="4"></circle><path d="M23 21v-2a4 4 0 0 0-3-3.87"></path><path d="M16 3.13a4 4 0 0 1 0 7.75"></path></svg>`;
  }
  return `<tr><td colspan="${cols}"><div class="empty"><div class="empty-icon" style="margin-bottom:12px;">${iconHtml}</div><div class="empty-text">${text}</div></div></td></tr>`;
}

// ─── PAGE NAV ────────────────────────────────────────────────
window.showPage = (page, el) => {
  document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
  document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
  const pageEl = document.getElementById('page-' + page);
  if (pageEl) pageEl.classList.add('active');
  if (el) el.classList.add('active');
  // Close sidebar on mobile after navigation
  if (window.innerWidth <= 768) closeSidebar();

  // Load specific page data
  if (page === 'broadcasts') {
    import('./broadcasts.js').then(m => m.loadBroadcasts());
  }

  // Fix Leaflet display bugs by invalidating map size when returning to overview
  if (page === 'overview') {
    import('./overview.js').then(m => {
      m.invalidateOverviewMap();
    });
  }
};

// ─── DASHBOARD REDIRECTS ────────────────────────────────────
window.goToReports = (filter) => {
  const navBtn = document.querySelector(`.sidebar-nav button[onclick*="'reports-list'"]`);

  if (filter === 'all') {
    window.openReportsView('all');
  } else if (filter === 'active' || filter === 'spam') {
    window.openReportsView('active');
    if (filter === 'spam') {
      const toggle = document.getElementById('show-spam-toggle');
      if (toggle) {
        toggle.checked = true;
        // In dual-column view, toggleSpamView just re-renders
        import('./reports.js').then(m => m.renderReports());
      }
    }
  } else if (filter === 'completed') {
    window.openReportsView('resolved');
  } else {
    window.showPage('reports-list', navBtn);
    return;
  }

  if (navBtn) {
    document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
    navBtn.classList.add('active');
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
    icon.innerHTML = isDark
      ? `<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" style="color:#F59E0B"><circle cx="12" cy="12" r="5"></circle><line x1="12" y1="1" x2="12" y2="3"></line><line x1="12" y1="21" x2="12" y2="23"></line><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"></line><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"></line><line x1="1" y1="12" x2="3" y2="12"></line><line x1="21" y1="12" x2="23" y2="12"></line><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"></line><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"></line></svg>`
      : `<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" style="color:#6366F1"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"></path></svg>`;
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
  showToast('Syncing data in real-time...');
  try {
    const reportsM = await import('./reports.js');
    const appsM = await import('./applications.js');
    const volunteersM = await import('./volunteers.js');
    await Promise.all([
      reportsM.loadReports(),
      appsM.loadApplications(),
      volunteersM.loadVolunteers()
    ]);
    showToast('Data synchronized');
  } catch (e) {
    showToast('Sync failed: ' + e.message);
  } finally {
    btns.forEach(btn => btn.classList.remove('spinning'));
  }
};
