import { db } from "./firebase-init.js";
import { collection, doc, updateDoc, serverTimestamp, query, orderBy, onSnapshot }
  from "https://www.gstatic.com/firebasejs/10.12.0/firebase-firestore.js";
import { appStatusBadge, formatTime, showToast, emptyRow, esc, renderPagination, exportToCSV, logAdminAction } from "./utils.js";

export let allApps = [];
let currentFilter = 'all';
let searchQuery = '';
let currentPage = 1;
const itemsPerPage = 10;
let unsubscribeApps = null;
let activeAppId = null;

export async function loadApplications() {
  return new Promise((resolve, reject) => {
    if (unsubscribeApps) unsubscribeApps();
    const q = query(collection(db, 'volunteer_applications'), orderBy('appliedAt', 'desc'));
    unsubscribeApps = onSnapshot(q, snap => {
      allApps = snap.docs.map(d => ({ id: d.id, ...d.data() }));

      const pendingCount = allApps.filter(a => a.status === 'pending').length;
      const badge = document.getElementById('apps-badge');
      if (badge) {
        badge.textContent = pendingCount;
        badge.style.display = pendingCount > 0 ? 'inline' : 'none';
      }

      try {
        import('./reports.js').then(m => m.updateHubStats());
      } catch(e) {}

      renderApps();

      if (activeAppId) {
        const activeApp = allApps.find(a => a.id === activeAppId);
        if (activeApp) renderAppModalContent(activeApp);
        else window.closeAppModal();
      }

      import('./overview.js').then(m => m.renderOverview());
      resolve();
    }, err => { reject(err); });
  });
}

export function unsubApps() { if (unsubscribeApps) { unsubscribeApps(); unsubscribeApps = null; } }

export function renderApps() {
  let filtered = currentFilter === 'all' ? allApps : allApps.filter(a => a.status === currentFilter);
  if (searchQuery) {
    filtered = filtered.filter(a => (a.email || '').toLowerCase().includes(searchQuery) || (a.skills || '').toLowerCase().includes(searchQuery));
  }

  const totalPages = Math.max(1, Math.ceil(filtered.length / itemsPerPage));
  if (currentPage > totalPages) currentPage = totalPages;
  const paginated = filtered.slice((currentPage - 1) * itemsPerPage, currentPage * itemsPerPage);

  const tbody = document.getElementById('apps-body');
  if (!tbody) return;

  if (paginated.length === 0) {
    tbody.innerHTML = emptyRow(5, 'empty', 'No applications found');
    renderPagination('apps-pagination', currentPage, totalPages, 'appsPrevPage()', 'appsNextPage()');
    return;
  }

  tbody.innerHTML = paginated.map(a => `
    <tr onclick="openAppDetails('${a.id}')">
      <td>
        <div style="font-weight:700; font-size:13px; color: var(--text-primary);">${esc(a.email)}</div>
        <div class="mono" style="font-size:10px; color: var(--text-secondary); opacity:0.6;">ID: ${a.id.substring(0,8)}</div>
      </td>
      <td style="font-size:12px; color:var(--text-secondary); max-width:240px; overflow:hidden; text-overflow:ellipsis; white-space:nowrap;">${esc(a.skills)}</td>
      <td>${appStatusBadge(a.status)}</td>
      <td style="font-size:11px; color:var(--text-secondary);">${formatTime(a.appliedAt)}</td>
      <td><span style="font-size:12px;color:var(--accent);font-weight:600">View →</span></td>
    </tr>
  `).join('');

  renderPagination('apps-pagination', currentPage, totalPages, 'appsPrevPage()', 'appsNextPage()');
}

window.filterApps = (filter, btn) => {
  currentFilter = filter; currentPage = 1;
  document.querySelectorAll('#page-applications .filter-btn').forEach(b => b.classList.remove('active'));
  if (btn) btn.classList.add('active');
  renderApps();
};

window.searchApps = (val) => { searchQuery = val.trim().toLowerCase(); currentPage = 1; renderApps(); };
window.appsPrevPage = () => { if (currentPage > 1) { currentPage--; renderApps(); } };
window.appsNextPage = () => { if (currentPage < Math.ceil(allApps.length / itemsPerPage)) { currentPage++; renderApps(); } };

window.exportApps = () => {
  const headers = ['ID', 'Email', 'Skills', 'Status', 'Applied At'];
  const rows = allApps.map(a => [a.id, a.email, a.skills, a.status, formatTime(a.appliedAt)]);
  exportToCSV(`reliefnet_applications_${new Date().toISOString().slice(0,10)}.csv`, headers, rows);
};

function renderAppModalContent(a) {
  const isPending = a.status === 'pending';
  document.getElementById('app-modal-body').innerHTML = `
    <div style="padding:40px; background: var(--surface); color: var(--text-primary);">
      <div style="display:flex; justify-content:space-between; align-items:start; margin-bottom:32px;">
        <div>
          <h2 style="font-size:24px; font-weight:800;">Volunteer Application</h2>
          <div class="mono" style="color:var(--text-secondary);">ID: ${a.id}</div>
        </div>
        ${appStatusBadge(a.status)}
      </div>

      <div class="card" style="padding:24px; margin-bottom:24px; background: var(--surface); border: 1px solid var(--border);">
        <label style="font-size:10px; font-weight:800; color:var(--text-secondary); text-transform:uppercase; display:block; margin-bottom:8px;">Applicant Email</label>
        <div style="font-size:16px; font-weight:600;">${esc(a.email)}</div>
        <div style="font-size:12px; color:var(--text-secondary); margin-top:4px;">Applied: ${formatTime(a.appliedAt)}</div>
      </div>

      <div style="display:flex; flex-direction:column; gap:24px; margin-bottom:32px;">
        <div class="card" style="padding:20px; background: var(--surface); border: 1px solid var(--border);">
           <label style="font-size:10px; font-weight:800; color:var(--text-secondary); text-transform:uppercase; display:block; margin-bottom:12px;">Skills & Experience</label>
           <div style="font-size:14px; line-height:1.6; color: var(--text-primary);">${esc(a.skills)}</div>
        </div>
        <div class="card" style="padding:20px; background: var(--surface); border: 1px solid var(--border);">
           <label style="font-size:10px; font-weight:800; color:var(--text-secondary); text-transform:uppercase; display:block; margin-bottom:12px;">Reason for Applying</label>
           <div style="font-size:14px; line-height:1.6; color: var(--text-primary);">${esc(a.reason)}</div>
        </div>
      </div>

      <div style="display:flex; gap:16px; justify-content:flex-end;">
         <button onclick="closeAppModal()" class="btn-back">Close</button>
         ${isPending ? `
           <button class="btn-primary" style="background:var(--critical); width:auto; padding:12px 32px;" onclick="rejectApp('${a.id}')">Reject Application</button>
           <button class="btn-primary" style="background:var(--success); width:auto; padding:12px 32px;" onclick="approveApp('${a.id}', '${a.uid || a.id}')">Approve Application</button>
         ` : ''}
      </div>
    </div>
  `;
}

window.openAppDetails = (id) => {
  const a = allApps.find(x => x.id === id);
  if (!a) return;
  activeAppId = id; renderAppModalContent(a);
  document.getElementById('app-modal').style.display = 'flex';
};

window.closeAppModal = () => { document.getElementById('app-modal').style.display = 'none'; activeAppId = null; };

window.approveApp = async (appId, userId) => {
  if (!confirm('Approve this volunteer application?')) return;
  const arr = new Uint32Array(2); crypto.getRandomValues(arr);
  const volunteerId = String(Number(BigInt(arr[0]) * 1000000n + BigInt(arr[1])) % 1000000000000).padStart(12, '0');
  try {
    await updateDoc(doc(db, 'volunteer_applications', appId), { status: 'approved', volunteerId, approvedAt: serverTimestamp() });
    await updateDoc(doc(db, 'users', userId), { isVolunteer: true, volunteerId });
    logAdminAction('approve_application', appId, { volunteerId, userId });
    showToast('Application approved');
    window.closeAppModal();
  } catch (e) { showToast(e.message); }
};

window.rejectApp = async (appId) => {
  if (!confirm('Reject this application?')) return;
  try {
    await updateDoc(doc(db, 'volunteer_applications', appId), { status: 'rejected' });
    logAdminAction('reject_application', appId);
    showToast('Application rejected');
    window.closeAppModal();
  } catch (e) { showToast(e.message); }
};
