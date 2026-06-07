import { db } from "./firebase-init.js";
import { collection, getDocs, doc, updateDoc, serverTimestamp }
  from "https://www.gstatic.com/firebasejs/10.12.0/firebase-firestore.js";
import { appStatusBadge, formatTime, showToast, emptyRow } from "./utils.js";

export let allApps = [];
let currentFilter = 'all';

export async function loadApplications() {
  const snap = await getDocs(collection(db, 'volunteer_applications'));
  allApps = snap.docs.map(d => ({ id: d.id, ...d.data() }));

  // Update sidebar badge
  const pending = allApps.filter(a => a.status === 'pending').length;
  const badge = document.getElementById('apps-badge');
  if (pending > 0) { badge.textContent = pending; badge.style.display = 'inline'; }
  else { badge.style.display = 'none'; }

  renderApps();
}

export function renderApps() {
  const filtered = currentFilter === 'all'
    ? allApps
    : allApps.filter(a => a.status === currentFilter);

  const tbody = document.getElementById('apps-body');
  if (filtered.length === 0) {
    tbody.innerHTML = emptyRow(6, '📭', 'No applications found');
    return;
  }
  tbody.innerHTML = filtered.map(a => `
    <tr>
      <td style="font-size:12px">${a.email || '—'}</td>
      <td><span style="font-size:12px;color:var(--gray-500)">${a.skills || '—'}</span></td>
      <td class="desc-cell" style="font-size:12px;color:var(--gray-500)">${a.reason || '—'}</td>
      <td>${appStatusBadge(a.status)}</td>
      <td style="font-size:12px;color:var(--gray-400)">${formatTime(a.appliedAt)}</td>
      <td>
        ${a.status === 'pending' ? `
          <button class="action-btn btn-approve" onclick="approveApp('${a.id}', '${a.uid || a.id}')">✅ Approve</button>
          <button class="action-btn btn-reject"  onclick="rejectApp('${a.id}')">❌ Reject</button>
        ` : `<span style="font-size:12px;color:var(--gray-400)">${a.status}</span>`}
      </td>
    </tr>
  `).join('');
}

window.filterApps = (filter, btn) => {
  currentFilter = filter;
  document.querySelectorAll('#page-applications .filter-btn').forEach(b => b.classList.remove('active'));
  btn.classList.add('active');
  renderApps();
};

window.approveApp = async (appId, userId) => {
  // Generate 12-digit volunteer ID
  const volunteerId = String(Math.floor(Math.random() * 1e12)).padStart(12, '0');
  try {
    await updateDoc(doc(db, 'volunteer_applications', appId), {
      status: 'approved',
      volunteerId,
      approvedAt: serverTimestamp()
    });
    // Also update the user document
    try {
      await updateDoc(doc(db, 'users', userId), { isVolunteer: true, volunteerId });
    } catch (_) { /* user doc may use different ID — that's ok */ }

    const a = allApps.find(x => x.id === appId);
    if (a) { a.status = 'approved'; a.volunteerId = volunteerId; }
    renderApps();
    import('./overview.js').then(m => m.renderOverview());
    showToast(`✅ Approved! Volunteer ID: ${volunteerId}`);
  } catch (e) { showToast('❌ Error: ' + e.message); }
};

window.rejectApp = async (appId) => {
  try {
    await updateDoc(doc(db, 'volunteer_applications', appId), { status: 'rejected' });
    const a = allApps.find(x => x.id === appId);
    if (a) a.status = 'rejected';
    renderApps();
    import('./overview.js').then(m => m.renderOverview());
    showToast('Application rejected');
  } catch (e) { showToast('❌ Error: ' + e.message); }
};
