import { db } from "./firebase-init.js";
import { collection, getDocs } from "https://www.gstatic.com/firebasejs/10.12.0/firebase-firestore.js";
import { formatTime, emptyRow } from "./utils.js";

export let allVolunteers = [];

export async function loadVolunteers() {
  const snap = await getDocs(collection(db, 'users'));
  allVolunteers = snap.docs
    .map(d => ({ id: d.id, ...d.data() }))
    .filter(u => u.isVolunteer);
  renderVolunteers();
}

export function renderVolunteers() {
  const tbody = document.getElementById('volunteers-body');
  if (allVolunteers.length === 0) {
    tbody.innerHTML = emptyRow(4, '👥', 'No verified volunteers yet');
    return;
  }
  tbody.innerHTML = allVolunteers.map(v => `
    <tr>
      <td><strong>${v.name || '—'}</strong></td>
      <td style="color:var(--gray-500)">@${v.username || '—'}</td>
      <td class="mono">${v.volunteerId || '—'}</td>
      <td style="font-size:12px;color:var(--gray-400)">${formatTime(v.updatedAt)}</td>
    </tr>
  `).join('');
}
