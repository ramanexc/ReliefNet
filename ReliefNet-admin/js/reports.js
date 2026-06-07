import { db } from "./firebase-init.js";
import { collection, getDocs, doc, updateDoc, orderBy, query, serverTimestamp }
  from "https://www.gstatic.com/firebasejs/10.12.0/firebase-firestore.js";
import { typeIcon, urgencyBadge, statusBadge, formatTime, showToast, loadingRow, emptyRow } from "./utils.js";

export let allReports = [];
let currentFilter = 'all';

export async function loadReports() {
  const snap = await getDocs(query(collection(db, 'reports'), orderBy('timestamp', 'desc')));
  allReports = snap.docs.map(d => ({ id: d.id, ...d.data() }));
  renderReports();
}

export function renderReports() {
  const filtered = currentFilter === 'all'
    ? allReports
    : currentFilter === 'completed'
      ? allReports.filter(r => r.status === 'completed')
      : allReports.filter(r => r.urgency === currentFilter);

  const tbody = document.getElementById('reports-body');
  if (filtered.length === 0) {
    tbody.innerHTML = emptyRow(6, '📭', 'No reports found');
    return;
  }
  tbody.innerHTML = filtered.map(r => `
    <tr>
      <td>${typeIcon(r.issueType)} ${r.issueType || '—'}</td>
      <td class="desc-cell">${r.description || '—'}</td>
      <td>${urgencyBadge(r.urgency)}</td>
      <td>${statusBadge(r.status)}</td>
      <td style="font-size:12px;color:var(--gray-400)">${formatTime(r.timestamp)}</td>
      <td>
        ${r.status !== 'completed'
          ? `<button class="action-btn btn-resolve" onclick="resolveReport('${r.id}')">✅ Resolve</button>`
          : `<span style="font-size:12px;color:var(--gray-400)">Done</span>`}
      </td>
    </tr>
  `).join('');
}

window.filterReports = (filter, btn) => {
  currentFilter = filter;
  document.querySelectorAll('#page-reports .filter-btn').forEach(b => b.classList.remove('active'));
  btn.classList.add('active');
  renderReports();
};

window.resolveReport = async (id) => {
  try {
    await updateDoc(doc(db, 'reports', id), {
      status: 'completed',
      resolvedAt: serverTimestamp()
    });
    const r = allReports.find(x => x.id === id);
    if (r) r.status = 'completed';
    renderReports();
    // refresh overview stats
    import('./overview.js').then(m => m.renderOverview());
    showToast('✅ Report marked as resolved');
  } catch (e) { showToast('❌ Error: ' + e.message); }
};
