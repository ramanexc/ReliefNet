import { db } from "./firebase-init.js";
import { collection, query, where, onSnapshot } from "https://www.gstatic.com/firebasejs/10.12.0/firebase-firestore.js";
import { formatTime, emptyRow, esc, renderPagination, exportToCSV } from "./utils.js";
import { allReports } from "./reports.js";

export let allVolunteers = [];
let searchQuery = '';
let currentPage = 1;
const itemsPerPage = 10;
let unsubscribeVolunteers = null;

export async function loadVolunteers() {
  return new Promise((resolve, reject) => {
    if (unsubscribeVolunteers) unsubscribeVolunteers();
    const q = query(collection(db, 'users'), where('isVolunteer', '==', true));
    unsubscribeVolunteers = onSnapshot(q, snap => {
      allVolunteers = snap.docs.map(d => ({ id: d.id, ...d.data() }));
      renderVolunteers();

      import('./overview.js').then(m => m.renderOverview());
      resolve();
    }, err => {
      console.error("Volunteers subscription error:", err);
      reject(err);
    });
  });
}

export function unsubVolunteers() {
  if (unsubscribeVolunteers) {
    unsubscribeVolunteers();
    unsubscribeVolunteers = null;
  }
}

export function renderVolunteers() {
  let filtered = allVolunteers;

  if (searchQuery) {
    filtered = filtered.filter(v =>
      (v.name || '').toLowerCase().includes(searchQuery) ||
      (v.volunteerId || '').toLowerCase().includes(searchQuery)
    );
  }

  filtered.sort((a, b) => (b.points || 0) - (a.points || 0));

  const totalPages = Math.max(1, Math.ceil(filtered.length / itemsPerPage));
  if (currentPage > totalPages) currentPage = totalPages;

  const start = (currentPage - 1) * itemsPerPage;
  const paginated = filtered.slice(start, start + itemsPerPage);

  const tbody = document.getElementById('volunteers-body');
  if (!tbody) return;

  if (paginated.length === 0) {
    tbody.innerHTML = emptyRow(6, 'users', 'No verified volunteers yet');
    renderPagination('volunteers-pagination', currentPage, totalPages, 'volunteersPrevPage()', 'volunteersNextPage()');
    return;
  }

  tbody.innerHTML = paginated.map((v, idx) => {
    const rank = start + idx + 1;
    let badge = rank;
    if (rank === 1) badge = '🥇'; else if (rank === 2) badge = '🥈'; else if (rank === 3) badge = '🥉';

    return `
    <tr onclick="openVolunteerProfile('${v.id}')">
      <td style="width: 60px; text-align: center; font-weight: 800; color:var(--info);">${badge}</td>
      <td><strong style="color: var(--text-primary);">${esc(v.name)}</strong></td>
      <td style="color:var(--text-secondary)">@${esc(v.username)}</td>
      <td class="mono" style="font-size:11px; color: var(--text-primary);">${esc(v.volunteerId)}</td>
      <td style="font-weight: 700; color: var(--success);">${v.points || 0}</td>
      <td style="font-size:11px; color:var(--text-secondary)">${formatTime(v.updatedAt)}</td>
    </tr>
  `;
  }).join('');

  renderPagination('volunteers-pagination', currentPage, totalPages, 'volunteersPrevPage()', 'volunteersNextPage()');
}

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
  const totalPages = Math.ceil(allVolunteers.length / itemsPerPage);
  if (currentPage < totalPages) {
    currentPage++;
    renderVolunteers();
  }
};

window.exportVolunteers = () => {
  const headers = ['ID', 'Name', 'Handle', 'Points', 'Joined'];
  const rows = allVolunteers.map(v => [v.volunteerId, v.name, v.username, v.points || 0, formatTime(v.updatedAt)]);
  exportToCSV(`reliefnet_volunteers_export_${new Date().toISOString().slice(0,10)}.csv`, headers, rows);
};

window.openVolunteerProfile = (uid) => {
  const v = allVolunteers.find(x => x.id === uid);
  if (!v) return;
  const assigned = allReports.filter(r => (r.assignedVolunteers || []).includes(uid));

  document.getElementById('vol-modal-body').innerHTML = `
    <div style="background: var(--surface); color: var(--text-primary); padding: 40px; border-radius: var(--radius-lg);">
      <div style="display:flex; justify-content:space-between; align-items:start; margin-bottom:32px;">
        <div>
          <h2 style="font-size:24px; font-weight:800;">Volunteer Profile</h2>
          <div class="mono" style="color:var(--text-secondary);">ID: ${v.volunteerId}</div>
        </div>
        <button onclick="closeVolunteerModal()" style="border:none; background:none; cursor:pointer; color:var(--text-secondary); font-weight: 600;">✕ Close</button>
      </div>

      <div class="card" style="padding:24px; margin-bottom:32px; display:grid; grid-template-columns: 1fr 1fr; gap:24px; background: var(--surface); border: 1px solid var(--border);">
         <div>
           <label style="font-size:10px; font-weight:800; color:var(--text-secondary); text-transform:uppercase; display:block; margin-bottom:4px;">Full Name</label>
           <div style="font-size:18px; font-weight:700;">${esc(v.name)}</div>
         </div>
         <div>
           <label style="font-size:10px; font-weight:800; color:var(--text-secondary); text-transform:uppercase; display:block; margin-bottom:4px;">Total Points</label>
           <div style="font-size:18px; font-weight:800; color:var(--success);">${v.points || 0}</div>
         </div>
      </div>

      <h3 style="font-size:12px; font-weight:800; text-transform:uppercase; letter-spacing:0.05em; margin-bottom:16px; color: var(--text-primary);">Assigned tasks (${assigned.length})</h3>
      <div class="card" style="max-height:300px; overflow-y:auto; border: 1px solid var(--border); background: var(--surface);">
         <table class="enterprise-table">
            <thead>
               <tr>
                 <th>Type</th>
                 <th>Status</th>
                 <th>Time</th>
               </tr>
            </thead>
            <tbody>
              ${assigned.length === 0 ? '<tr><td colspan="3" style="text-align: center; color: var(--text-secondary);">No mission history</td></tr>' : assigned.map(r => `
                <tr>
                  <td><strong style="color: var(--text-primary);">${esc(r.issueType)}</strong></td>
                  <td>${statusBadge(r.status)}</td>
                  <td style="font-size:11px; color: var(--text-secondary);">${formatTime(r.timestamp)}</td>
                </tr>
              `).join('')}
            </tbody>
         </table>
      </div>
    </div>
  `;
  document.getElementById('volunteer-modal').style.display = 'flex';
};

window.closeVolunteerModal = () => document.getElementById('volunteer-modal').style.display = 'none';
