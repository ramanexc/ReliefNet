import { db } from "./firebase-init.js";
import { collection, query, where, onSnapshot } from "https://www.gstatic.com/firebasejs/10.12.0/firebase-firestore.js";
import { formatTime, emptyRow, esc, renderPagination, exportToCSV } from "./utils.js";
import { allReports } from "./reports.js";

export let allVolunteers = [];
let searchQuery = '';
let currentPage = 1;
const itemsPerPage = 10;
let unsubscribeVolunteers = null;

// ─── LOAD (REAL-TIME LISTENER) ───────────────────────────────
export async function loadVolunteers() {
  return new Promise((resolve, reject) => {
    if (unsubscribeVolunteers) unsubscribeVolunteers();
    const q = query(collection(db, 'users'), where('isVolunteer', '==', true));
    unsubscribeVolunteers = onSnapshot(q, snap => {
      allVolunteers = snap.docs.map(d => ({ id: d.id, ...d.data() }));
      renderVolunteers();
      
      // Trigger overview update dynamically
      import('./overview.js').then(m => m.renderOverview());
      resolve();
    }, err => {
      console.error("Volunteers subscription error:", err);
      reject(err);
    });
  });
}

// ─── UNSUBSCRIBE LISTENER ────────────────────────────────────
export function unsubVolunteers() {
  if (unsubscribeVolunteers) {
    unsubscribeVolunteers();
    unsubscribeVolunteers = null;
  }
}

// ─── RENDER TABLE ────────────────────────────────────────────
export function renderVolunteers() {
  let filtered = allVolunteers;

  if (searchQuery) {
    filtered = filtered.filter(v => 
      (v.name || '').toLowerCase().includes(searchQuery) ||
      (v.username || '').toLowerCase().includes(searchQuery) ||
      (v.volunteerId || '').toLowerCase().includes(searchQuery)
    );
  }

  const totalItems = filtered.length;
  const totalPages = Math.max(1, Math.ceil(totalItems / itemsPerPage));
  if (currentPage > totalPages) currentPage = totalPages;

  const start = (currentPage - 1) * itemsPerPage;
  const paginated = filtered.slice(start, start + itemsPerPage);

  const tbody = document.getElementById('volunteers-body');
  if (paginated.length === 0) {
    tbody.innerHTML = emptyRow(5, '👥', 'No verified volunteers yet');
    renderPagination('volunteers-pagination', currentPage, totalPages, 'volunteersPrevPage()', 'volunteersNextPage()');
    return;
  }

  tbody.innerHTML = paginated.map(v => `
    <tr onclick="openVolunteerProfile('${v.id}')">
      <td><strong>${esc(v.name)}</strong></td>
      <td style="color:var(--gray-500)">@${esc(v.username)}</td>
      <td class="mono">${esc(v.volunteerId)}</td>
      <td style="font-size:12px;color:var(--gray-400)">${formatTime(v.updatedAt)}</td>
      <td><span style="font-size:12px;color:var(--blue);font-weight:600">View →</span></td>
    </tr>
  `).join('');

  renderPagination('volunteers-pagination', currentPage, totalPages, 'volunteersPrevPage()', 'volunteersNextPage()');
}

// ─── SEARCH / PAGINATION ACTIONS ─────────────────────────────
window.searchVolunteers = (val) => {
  searchQuery = val.trim().toLowerCase();
  currentPage = 1;
  renderVolunteers();
};

window.volunteersPrevPage = () => {
  if (currentPage > 1) {
    currentPage--;
    renderVolunteers();
  }
};

window.volunteersNextPage = () => {
  let filtered = allVolunteers;
  if (searchQuery) {
    filtered = filtered.filter(v => 
      (v.name || '').toLowerCase().includes(searchQuery) ||
      (v.username || '').toLowerCase().includes(searchQuery) ||
      (v.volunteerId || '').toLowerCase().includes(searchQuery)
    );
  }
  const totalPages = Math.ceil(filtered.length / itemsPerPage);
  if (currentPage < totalPages) {
    currentPage++;
    renderVolunteers();
  }
};

// ─── CSV DATA EXPORT ──────────────────────────────────────────
window.exportVolunteers = () => {
  const headers = ['User ID', 'Name', 'Username', 'Volunteer ID', 'Joined At'];
  const rows = allVolunteers.map(v => [
    v.id,
    v.name || '',
    v.username || '',
    v.volunteerId || '',
    v.updatedAt?.toDate ? v.updatedAt.toDate().toISOString() : v.updatedAt || ''
  ]);
  exportToCSV(`reliefnet_volunteers_${new Date().toISOString().split('T')[0]}.csv`, headers, rows);
};

// ─── VOLUNTEER DETAIL PROFILE MODAL ──────────────────────────
window.openVolunteerProfile = (uid) => {
  const v = allVolunteers.find(x => x.id === uid);
  if (!v) return;

  // Find reports assigned to this volunteer
  const assignedReports = allReports.filter(r => (r.assignedVolunteers || []).includes(uid));
  const activeReports = assignedReports.filter(r => r.status !== 'completed');
  const resolvedReports = assignedReports.filter(r => r.status === 'completed');

  document.getElementById('vol-modal-body').innerHTML = `
    <div style="display:flex;align-items:flex-start;justify-content:space-between;margin-bottom:20px">
      <div>
        <h2 id="vol-modal-title" style="font-size:20px;font-weight:700;color:var(--gray-900)">Volunteer Profile</h2>
        <div style="font-size:13px;color:var(--gray-500);margin-top:2px">ID: ${esc(v.volunteerId)}</div>
      </div>
      <button onclick="closeVolunteerModal()" style="background:var(--gray-100);border:none;border-radius:8px;padding:6px 12px;cursor:pointer;font-size:18px;color:var(--gray-500)">✕</button>
    </div>

    <!-- PROFILE INFO -->
    <div class="modal-section" style="margin-bottom:16px;">
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;">
        <div>
          <div style="font-size:10px;font-weight:700;color:var(--gray-400);text-transform:uppercase;letter-spacing:0.05em;margin-bottom:4px;">Full Name</div>
          <div style="font-size:15px;font-weight:600;">${esc(v.name)}</div>
        </div>
        <div>
          <div style="font-size:10px;font-weight:700;color:var(--gray-400);text-transform:uppercase;letter-spacing:0.05em;margin-bottom:4px;">Username</div>
          <div style="font-size:15px;font-weight:600;color:var(--gray-500)">@${esc(v.username)}</div>
        </div>
        <div>
          <div style="font-size:10px;font-weight:700;color:var(--gray-400);text-transform:uppercase;letter-spacing:0.05em;margin-bottom:4px;">Joined Date</div>
          <div style="font-size:14px;">${formatTime(v.updatedAt)}</div>
        </div>
        <div>
          <div style="font-size:10px;font-weight:700;color:var(--gray-400);text-transform:uppercase;letter-spacing:0.05em;margin-bottom:4px;">Status</div>
          <div><span class="badge badge-approved">Active</span></div>
        </div>
      </div>
    </div>

    <!-- METRICS -->
    <div style="display:grid;grid-template-columns:repeat(3, 1fr);gap:12px;margin-bottom:16px;">
      <div class="modal-section" style="text-align:center;">
        <div style="font-size:10px;font-weight:700;color:var(--gray-400);text-transform:uppercase;letter-spacing:0.05em;">Assigned</div>
        <div style="font-size:24px;font-weight:700;font-family:'DM Mono',monospace;color:var(--blue);margin-top:4px;">${assignedReports.length}</div>
      </div>
      <div class="modal-section" style="text-align:center;">
        <div style="font-size:10px;font-weight:700;color:var(--gray-400);text-transform:uppercase;letter-spacing:0.05em;">Active Tasks</div>
        <div style="font-size:24px;font-weight:700;font-family:'DM Mono',monospace;color:var(--orange);margin-top:4px;">${activeReports.length}</div>
      </div>
      <div class="modal-section" style="text-align:center;">
        <div style="font-size:10px;font-weight:700;color:var(--gray-400);text-transform:uppercase;letter-spacing:0.05em;">Resolved</div>
        <div style="font-size:24px;font-weight:700;font-family:'DM Mono',monospace;color:var(--green);margin-top:4px;">${resolvedReports.length}</div>
      </div>
    </div>

    <!-- ACTIVE ASSIGNMENTS -->
    <div class="modal-section" style="margin-bottom:16px; max-height:200px; overflow-y:auto;">
      <div class="modal-section-title" style="color:var(--orange)">📋 Active Tasks</div>
      ${activeReports.length === 0
        ? `<div style="color:var(--gray-400);font-size:13px;padding:8px 0">No active assignments</div>`
        : activeReports.map(r => `
            <div style="display:flex;justify-content:space-between;align-items:center;padding:8px 0;border-bottom:1px solid var(--gray-100);">
              <div style="font-size:13px;">
                <strong>${esc(r.issueType)}</strong>
                <span style="font-size:11px;color:var(--gray-400);margin-left:8px;">${formatTime(r.timestamp)}</span>
              </div>
              <button onclick="window.closeVolunteerModal(); window.openReport('${r.id}')" class="volunteer-link" style="font-size:12px;">View Report →</button>
            </div>
          `).join('')}
    </div>

    <!-- COMPLETED ASSIGNMENTS -->
    <div class="modal-section" style="max-height:200px; overflow-y:auto;">
      <div class="modal-section-title" style="color:var(--green)">✅ Resolved Tasks</div>
      ${resolvedReports.length === 0
        ? `<div style="color:var(--gray-400);font-size:13px;padding:8px 0">No resolved tasks yet</div>`
        : resolvedReports.map(r => `
            <div style="display:flex;justify-content:space-between;align-items:center;padding:8px 0;border-bottom:1px solid var(--gray-100);">
              <div style="font-size:13px;">
                <strong>${esc(r.issueType)}</strong>
                <span style="font-size:11px;color:var(--gray-400);margin-left:8px;">${formatTime(r.resolvedAt)}</span>
              </div>
              <button onclick="window.closeVolunteerModal(); window.openReport('${r.id}')" class="volunteer-link" style="font-size:12px;">View Report →</button>
            </div>
          `).join('')}
    </div>
  `;

  document.getElementById('volunteer-modal').style.display = 'flex';
};

window.closeVolunteerModal = () => {
  document.getElementById('volunteer-modal').style.display = 'none';
};

// Close backdrop listener for volunteer-modal
document.addEventListener('click', e => {
  if (e.target.id === 'volunteer-modal') window.closeVolunteerModal();
});

// Escape key listener for volunteer-modal
document.addEventListener('keydown', e => {
  if (e.key === 'Escape') {
    window.closeVolunteerModal();
  }
});
