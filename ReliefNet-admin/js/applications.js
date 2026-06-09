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
let activeAppId = null; // Currently open application detail modal

// ─── LOAD (REAL-TIME LISTENER) ───────────────────────────────
export async function loadApplications() {
  return new Promise((resolve, reject) => {
    if (unsubscribeApps) unsubscribeApps();
    const q = query(collection(db, 'volunteer_applications'), orderBy('appliedAt', 'desc'));
    unsubscribeApps = onSnapshot(q, snap => {
      allApps = snap.docs.map(d => ({ id: d.id, ...d.data() }));

      // Update sidebar badge
      const pending = allApps.filter(a => a.status === 'pending').length;
      const badge = document.getElementById('apps-badge');
      if (badge) {
        if (pending > 0) { badge.textContent = pending; badge.style.display = 'inline'; }
        else { badge.style.display = 'none'; }
      }

      renderApps();
      
      // If details modal is open, dynamically re-render its dynamic elements
      if (activeAppId) {
        const activeApp = allApps.find(a => a.id === activeAppId);
        if (activeApp) {
          renderAppModalContent(activeApp);
        } else {
          window.closeAppModal();
        }
      }

      // Trigger overview update dynamically
      import('./overview.js').then(m => m.renderOverview());
      resolve();
    }, err => {
      console.error("Applications subscription error:", err);
      reject(err);
    });
  });
}

// ─── UNSUBSCRIBE LISTENER ────────────────────────────────────
export function unsubApps() {
  if (unsubscribeApps) {
    unsubscribeApps();
    unsubscribeApps = null;
  }
}

// ─── RENDER TABLE ────────────────────────────────────────────
export function renderApps() {
  let filtered = currentFilter === 'all'
    ? allApps
    : allApps.filter(a => a.status === currentFilter);

  if (searchQuery) {
    filtered = filtered.filter(a => 
      (a.email || '').toLowerCase().includes(searchQuery) ||
      (a.skills || '').toLowerCase().includes(searchQuery) ||
      (a.reason || '').toLowerCase().includes(searchQuery)
    );
  }

  const totalItems = filtered.length;
  const totalPages = Math.max(1, Math.ceil(totalItems / itemsPerPage));
  if (currentPage > totalPages) currentPage = totalPages;

  const start = (currentPage - 1) * itemsPerPage;
  const paginated = filtered.slice(start, start + itemsPerPage);

  const tbody = document.getElementById('apps-body');
  if (paginated.length === 0) {
    tbody.innerHTML = emptyRow(6, 'empty', 'No applications found');
    renderPagination('apps-pagination', currentPage, totalPages, 'appsPrevPage()', 'appsNextPage()');
    return;
  }

  tbody.innerHTML = paginated.map(a => `
    <tr onclick="openAppDetails('${a.id}')">
      <td style="font-size:12px"><strong>${esc(a.email)}</strong></td>
      <td><span style="font-size:12px;color:var(--gray-500)">${esc(a.skills)}</span></td>
      <td class="desc-cell" style="font-size:12px;color:var(--gray-500)">${esc(a.reason)}</td>
      <td>${appStatusBadge(a.status)}</td>
      <td style="font-size:12px;color:var(--gray-400)">${formatTime(a.appliedAt)}</td>
      <td><span style="font-size:12px;color:var(--blue);font-weight:600">View →</span></td>
    </tr>
  `).join('');

  renderPagination('apps-pagination', currentPage, totalPages, 'appsPrevPage()', 'appsNextPage()');
}

// ─── FILTER ──────────────────────────────────────────────────
window.filterApps = (filter, btn) => {
  currentFilter = filter;
  currentPage = 1;
  document.querySelectorAll('#page-applications .filter-btn').forEach(b => b.classList.remove('active'));
  btn.classList.add('active');
  renderApps();
};

// ─── SEARCH / PAGINATION ACTIONS ─────────────────────────────
window.searchApps = (val) => {
  searchQuery = val.trim().toLowerCase();
  currentPage = 1;
  renderApps();
};

window.appsPrevPage = () => {
  if (currentPage > 1) {
    currentPage--;
    renderApps();
  }
};

window.appsNextPage = () => {
  let filtered = currentFilter === 'all'
    ? allApps
    : allApps.filter(a => a.status === currentFilter);

  if (searchQuery) {
    filtered = filtered.filter(a => 
      (a.email || '').toLowerCase().includes(searchQuery) ||
      (a.skills || '').toLowerCase().includes(searchQuery) ||
      (a.reason || '').toLowerCase().includes(searchQuery)
    );
  }
  const totalPages = Math.ceil(filtered.length / itemsPerPage);
  if (currentPage < totalPages) {
    currentPage++;
    renderApps();
  }
};

// ─── CSV DATA EXPORT ──────────────────────────────────────────
window.exportApps = () => {
  const headers = ['Application ID', 'User ID', 'Email', 'Skills', 'Reason', 'Status', 'Applied At', 'Volunteer ID', 'Approved At'];
  const rows = allApps.map(a => [
    a.id,
    a.uid || '',
    a.email || '',
    a.skills || '',
    a.reason || '',
    a.status || 'pending',
    a.appliedAt?.toDate ? a.appliedAt.toDate().toISOString() : a.appliedAt || '',
    a.volunteerId || '',
    a.approvedAt?.toDate ? a.approvedAt.toDate().toISOString() : a.approvedAt || ''
  ]);
  exportToCSV(`reliefnet_applications_${new Date().toISOString().split('T')[0]}.csv`, headers, rows);
};

// ─── DYNAMIC MODAL REDRAW ────────────────────────────────────
function renderAppModalContent(a) {
  const isPending = a.status === 'pending';
  const isApproved = a.status === 'approved';
  const isRejected = a.status === 'rejected';

  document.getElementById('app-modal-body').innerHTML = `
    <div style="display:flex;align-items:flex-start;justify-content:space-between;margin-bottom:20px">
      <div>
        <h2 id="app-modal-title" style="font-size:20px;font-weight:700;color:var(--gray-900)">Volunteer Application</h2>
        <div style="font-size:12px;color:var(--gray-400);font-family:'DM Mono',monospace;margin-top:2px">ID: ${a.id}</div>
      </div>
      <button onclick="closeAppModal()" style="background:var(--gray-100);border:none;border-radius:8px;padding:6px 12px;cursor:pointer;font-size:18px;color:var(--gray-500)">✕</button>
    </div>

    <div style="display:flex;flex-direction:column;gap:16px">
      <!-- Applicant Info -->
      <div class="modal-section">
        <div class="modal-section-title"><svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"></path><polyline points="22,6 12,13 2,6"></polyline></svg> Applicant Email</div>
        <div style="font-size:15px;font-weight:600;">${esc(a.email)}</div>
        <div style="font-size:12px;color:var(--gray-400);margin-top:4px">Applied: ${formatTime(a.appliedAt)}</div>
      </div>

      <!-- Skills -->
      <div class="modal-section">
        <div class="modal-section-title"><svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"></path></svg> Skills & Experience</div>
        <div style="font-size:13px;color:var(--gray-700);line-height:1.5">${esc(a.skills)}</div>
      </div>

      <!-- Reason -->
      <div class="modal-section">
        <div class="modal-section-title"><svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"></path><path d="M18.5 2.5a2.121 2.121 0 1 1 3 3L12 15l-4 1 1-4 9.5-9.5z"></path></svg> Reason for Applying</div>
        <div style="font-size:13px;color:var(--gray-700);line-height:1.6;white-space:pre-wrap;">${esc(a.reason)}</div>
      </div>

      <!-- Status Section -->
      <div class="modal-section" style="${isApproved ? 'border-color:var(--green);background:var(--green-light)' : isRejected ? 'border-color:var(--red);background:var(--red-light)' : 'border-color:var(--orange);background:var(--orange-light)'}">
        <div class="modal-section-title" style="color:${isApproved ? 'var(--green)' : isRejected ? 'var(--red)' : 'var(--orange)'}">Status: ${a.status || 'pending'}</div>
        ${isApproved ? `
          <div style="font-size:13px;color:var(--gray-700)">
            Approved: ${formatTime(a.approvedAt)}<br>
            Assigned Volunteer ID: <strong class="mono">${esc(a.volunteerId)}</strong>
          </div>
          <button onclick="window.closeAppModal(); window.openVolunteerProfile('${a.uid || a.id}')" class="btn-primary" style="margin-top:12px;width:auto;padding:8px 16px;font-size:13px;">View Volunteer Profile →</button>
        ` : isRejected ? `
          <div style="font-size:13px;color:var(--gray-700)">This application was rejected.</div>
        ` : `
          <div style="font-size:13px;color:var(--gray-700);margin-bottom:12px;">This application is awaiting review.</div>
          <div style="display:flex;gap:8px;">
            <button class="action-btn btn-approve" id="modal-approve-btn" onclick="approveApp('${a.id}', '${a.uid || a.id}')" style="padding:10px 16px;font-size:13px;display:inline-flex;align-items:center;gap:6px;"><svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" style="width:14px;height:14px;"><polyline points="20 6 9 17 4 12"></polyline></svg> Approve Application</button>
            <button class="action-btn btn-reject" id="modal-reject-btn" onclick="rejectApp('${a.id}')" style="padding:10px 16px;font-size:13px;display:inline-flex;align-items:center;gap:6px;"><svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" style="width:14px;height:14px;"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg> Reject Application</button>
          </div>
        `}
      </div>
    </div>
  `;
}

// ─── OPEN APPLICATION DETAILS ────────────────────────────────
window.openAppDetails = (id) => {
  const a = allApps.find(x => x.id === id);
  if (!a) return;
  activeAppId = id;
  renderAppModalContent(a);
  document.getElementById('app-modal').style.display = 'flex';
};

// ─── CLOSE APPLICATION DETAILS ────────────────────────────────
window.closeAppModal = () => {
  document.getElementById('app-modal').style.display = 'none';
  activeAppId = null;
};

// Backdrop click
document.addEventListener('click', e => {
  if (e.target.id === 'app-modal') window.closeAppModal();
});

// Escape key listener (only close if volunteer modal is not overlaying)
document.addEventListener('keydown', e => {
  if (e.key === 'Escape' && activeAppId) {
    const volModal = document.getElementById('volunteer-modal');
    if (volModal && volModal.style.display === 'flex') return;
    window.closeAppModal();
  }
});

// ─── ACTIONS ──────────────────────────────────────────────────
window.approveApp = async (appId, userId) => {
  if (!confirm('Approve this volunteer application? This will grant volunteer access.')) return;
  
  // Generate 12-digit volunteer ID using crypto for better randomness
  const arr = new Uint32Array(2);
  crypto.getRandomValues(arr);
  const volunteerId = String(Number(BigInt(arr[0]) * 1000000n + BigInt(arr[1])) % 1000000000000).padStart(12, '0');
  
  const btn = document.getElementById('modal-approve-btn'); 
  if (btn) { btn.disabled = true; btn.innerHTML = 'Approving...'; }
  
  try {
    await updateDoc(doc(db, 'volunteer_applications', appId), {
      status: 'approved',
      volunteerId,
      approvedAt: serverTimestamp()
    });
    
    // Log action
    logAdminAction('approve_application', appId, { volunteerId, userId });

    // Also update the user document
    try {
      await updateDoc(doc(db, 'users', userId), { isVolunteer: true, volunteerId });
    } catch (err) {
      console.warn('Could not update user doc:', err);
      showToast('Approved, but user profile update failed. User ID may differ.');
    }

    const a = allApps.find(x => x.id === appId);
    if (a) { a.status = 'approved'; a.volunteerId = volunteerId; }
    renderApps();
    showToast(`Approved! Volunteer ID: ${volunteerId}`);
  } catch (e) {
    if (btn) { btn.disabled = false; btn.innerHTML = `<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" style="width:14px;height:14px;"><polyline points="20 6 9 17 4 12"></polyline></svg> Approve Application`; }
    showToast('Error: ' + e.message);
  }
};

window.rejectApp = async (appId) => {
  if (!confirm('Reject this application? This action cannot be undone.')) return;
  
  const btn = document.getElementById('modal-reject-btn'); 
  if (btn) { btn.disabled = true; btn.innerHTML = 'Rejecting...'; }
  
  try {
    await updateDoc(doc(db, 'volunteer_applications', appId), { status: 'rejected' });
    
    // Log action
    logAdminAction('reject_application', appId);

    const a = allApps.find(x => x.id === appId);
    if (a) a.status = 'rejected';
    renderApps();
    showToast('Application rejected');
  } catch (e) {
    if (btn) { btn.disabled = false; btn.innerHTML = `<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" style="width:14px;height:14px;"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg> Reject Application`; }
    showToast('Error: ' + e.message);
  }
};
