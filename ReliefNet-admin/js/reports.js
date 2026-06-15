import { db } from "./firebase-init.js";
import {
  collection, doc, updateDoc, increment, arrayUnion, arrayRemove, orderBy,
  query, serverTimestamp, onSnapshot, getDoc,
} from "https://www.gstatic.com/firebasejs/10.12.0/firebase-firestore.js";
import {
  typeIcon, urgencyBadge, statusBadge, formatTime, showToast, emptyRow, esc,
  exportToCSV, logAdminAction,
} from "./utils.js";
import { allVolunteers } from "./volunteers.js";
import { allApps } from "./applications.js";

export let allReports = [];
let searchQuery = "";
let currentStatusFilter = "all";
let currentUrgencyFilter = "all";
let currentTypeFilter = "all";
let activeReportId = null;
let previousFocus = null;
let unsubscribeReports = null;
let detailMapInstance = null;

// ─── LOAD (REAL-TIME LISTENER) ───────────────────────────────
export async function loadReports() {
  return new Promise((resolve, reject) => {
    if (unsubscribeReports) unsubscribeReports();
    const q = query(collection(db, "reports"), orderBy("timestamp", "desc"));
    unsubscribeReports = onSnapshot(
      q,
      (snap) => {
        allReports = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
        renderReports();
        updateReportsBadge();
        updateHubStats();

        if (activeReportId) {
          const activeRep = allReports.find((r) => r.id === activeReportId);
          if (activeRep) renderModalContentOnly(activeRep);
          else window.closeModal();
        }

        import("./overview.js").then((m) => m.renderOverview());
        resolve();
      },
      (err) => { reject(err); },
    );
  });
}

export function unsubReports() {
  if (unsubscribeReports) {
    unsubscribeReports();
    unsubscribeReports = null;
  }
}

export function updateHubStats() {
  const activeCount = allReports.filter(r => r.status !== 'completed' && r.status !== 'suspected_spam' && r.status !== 'flagged').length;
  const resolvedCount = allReports.filter(r => r.status === 'completed').length;
  const totalCount = allReports.length;
  const spamCount = allReports.filter(r => r.status === 'suspected_spam' || r.status === 'flagged').length;
  const pendingAppsCount = allApps.filter(a => a.status === 'pending').length;

  // Sync with KPI widgets
  const setVal = (id, val) => {
    const el = document.getElementById(id);
    if(el) el.textContent = val;
  };
  setVal('stat-active', activeCount);
  setVal('stat-resolved', resolvedCount);
  setVal('stat-total', totalCount);
  setVal('stat-spam', spamCount);
  setVal('stat-pending-apps', pendingAppsCount);
}

// ─── NAVIGATION & FILTERING ──────────────────────────────────
window.openReportsView = (view) => {
  if (view === 'active') {
    currentStatusFilter = 'active';
  } else if (view === 'resolved') {
    currentStatusFilter = 'completed';
  } else if (view === 'spam') {
    currentStatusFilter = 'spam';
  } else {
    currentStatusFilter = 'all';
  }

  // Reset other filters when navigating from overview widgets
  currentUrgencyFilter = 'all';
  currentTypeFilter = 'all';

  // Update button classes in UI
  updateFilterButtonsUI();

  renderReports();
  const navBtn = document.querySelector(`.sidebar-nav button[onclick*="'reports-list'"]`);
  window.showPage('reports-list', navBtn);
};

function updateFilterButtonsUI() {
  document.querySelectorAll('.status-filter-btn').forEach(b => {
    b.classList.toggle('active', b.getAttribute('onclick').includes(`'${currentStatusFilter}'`));
  });
  document.querySelectorAll('.urgency-filter-btn').forEach(b => {
    b.classList.toggle('active', b.getAttribute('onclick').includes(`'${currentUrgencyFilter}'`));
  });
  document.querySelectorAll('.type-filter-btn').forEach(b => {
    b.classList.toggle('active', b.getAttribute('onclick').includes(`'${currentTypeFilter}'`));
  });
}

window.filterReports = (filter, type, btn) => {
  if (type === 'status') {
    currentStatusFilter = filter;
  } else if (type === 'urgency') {
    currentUrgencyFilter = filter;
  } else if (type === 'incident') {
    currentTypeFilter = filter;
  }

  updateFilterButtonsUI();
  renderReports();
};

// ─── RENDER (DUAL COLUMN) ────────────────────────────────────
export function renderReports() {
  let filtered = allReports;

  // 1. Filter by search
  if (searchQuery) {
    filtered = filtered.filter(r =>
      (r.issueType || "").toLowerCase().includes(searchQuery) ||
      (r.description || "").toLowerCase().includes(searchQuery) ||
      (r.id || "").toLowerCase().includes(searchQuery)
    );
  }

  // 2. Filter by Urgency
  if (currentUrgencyFilter !== "all") {
    filtered = filtered.filter(r => r.urgency === currentUrgencyFilter);
  }

  // 3. Filter by Incident Type
  if (currentTypeFilter !== "all") {
    filtered = filtered.filter(r => (r.issueType || "").toLowerCase() === currentTypeFilter.toLowerCase());
  }

  // 4. Split into Active and Resolved based on Status Filter
  const activeReports = filtered.filter(r => {
    const isCompleted = r.status === "completed";
    const isSpam = r.status === "suspected_spam" || r.status === "flagged";

    if (currentStatusFilter === 'active') return !isCompleted && !isSpam;
    if (currentStatusFilter === 'completed') return isCompleted;
    if (currentStatusFilter === 'spam') return isSpam;

    // 'all' status filter shows active in the left column
    return !isCompleted && !isSpam;
  });

  const resolvedReports = filtered.filter(r => {
    const isCompleted = r.status === "completed";
    // Resolved column only shows completed reports
    if (currentStatusFilter === 'active' || currentStatusFilter === 'spam') return false;
    return isCompleted;
  });

  const renderCol = (tbodyId, items) => {
    const tbody = document.getElementById(tbodyId);
    if (!tbody) return;
    if (items.length === 0) {
      tbody.innerHTML = emptyRow(3, "empty", "No reports found");
      return;
    }
    tbody.innerHTML = items.map(r => `
      <tr onclick="openReport('${r.id}')">
        <td>
          <div style="display:flex; align-items:center; gap:12px;">
            ${typeIcon(r.issueType)}
            <div>
              <div style="font-weight:700; font-size:13px; color: var(--text-primary);">${esc(r.issueType)}</div>
              <div class="mono" style="font-size:10px; color: var(--text-secondary); opacity:0.6;">ID: ${r.id.substring(0,8)}</div>
            </div>
          </div>
        </td>
        <td style="font-size:11px; color: var(--text-secondary); white-space:nowrap;">
          ${formatTime(r.timestamp).split(',')[0]}<br>${formatTime(r.timestamp).split(',')[1]}
        </td>
        <td>${urgencyBadge(r.urgency)}</td>
      </tr>
    `).join("");
  };

  renderCol("reports-active-body", activeReports);
  renderCol("reports-resolved-body", resolvedReports);
}

window.searchReports = (val) => {
  searchQuery = val.trim().toLowerCase();
  renderReports();
};

window.exportReports = () => {
  const headers = ["ID", "Type", "Urgency", "Status", "Contact", "Time"];
  const rows = allReports.map(r => [r.id, r.issueType, r.urgency, r.status, r.submittedBy, formatTime(r.timestamp)]);
  exportToCSV(`reliefnet_reports_export_${new Date().toISOString().slice(0,10)}.csv`, headers, rows);
};

// ─── MODAL RENDER ────────────────────────────────────────────
function renderModalContentOnly(r) {
  const assigned = r.assignedVolunteers || [];
  const assignedHtml = assigned.length === 0
    ? `<span style="color:var(--text-secondary); font-size:13px;">No volunteers assigned</span>`
    : assigned.map(uid => {
        const v = allVolunteers.find(x => x.id === uid);
        return `<div class="assigned-vol-chip" style="background: var(--bg-secondary); border: 1px solid var(--border); padding: 4px 8px; border-radius: 4px; display: inline-flex; align-items: center; gap: 8px; margin-right: 4px; margin-bottom: 4px; font-size: 12px; color: var(--text-primary);">
          ${esc(v?.name || uid)}
          <button onclick="removeVolunteer('${uid}')" style="background: none; border: none; color: var(--critical); cursor: pointer; font-weight: bold;">✕</button>
        </div>`;
      }).join("");

  const available = allVolunteers.filter(v => !assigned.includes(v.id));
  const lat = Number(r.lat); const lng = Number(r.lng);
  const hasCoords = !isNaN(lat) && !isNaN(lng);

  document.getElementById("modal-body").innerHTML = `
    <div style="display:grid; grid-template-columns: 1fr 380px; height: 90vh; background: var(--surface);">
      <div style="display:flex; flex-direction:column; border-right:1px solid var(--border);">
        <div class="panel-header" style="padding:24px 32px; background: var(--bg-secondary); display: flex; justify-content: space-between; align-items: center;">
          <div style="display:flex; align-items:center; gap:16px;">
            ${typeIcon(r.issueType)}
            <div>
              <h2 style="font-size:24px; font-weight:800; color: var(--text-primary);">Report Details</h2>
              <div class="mono" style="color:var(--text-secondary);">ID: ${r.id}</div>
            </div>
          </div>
          <div style="display:flex; gap:12px;">
            ${urgencyBadge(r.urgency)}
            ${statusBadge(r.status)}
          </div>
        </div>

        <div style="flex:1; overflow-y:auto; padding:32px;">
          <div style="margin-bottom:32px;">
            <label style="font-size:10px; font-weight:800; color:var(--text-secondary); text-transform:uppercase; letter-spacing:0.1em; display:block; margin-bottom:12px;">Description</label>
            <p style="font-size:16px; color:var(--text-primary); line-height:1.6;">${esc(r.description)}</p>
          </div>

          <div style="display:grid; grid-template-columns:1fr 1fr; gap:32px; margin-bottom:32px;">
             <div>
               <label style="font-size:10px; font-weight:800; color:var(--text-secondary); text-transform:uppercase; margin-bottom:8px; display:block;">Coordinates</label>
               <div class="mono" style="font-size:13px; color: var(--text-primary);">${hasCoords ? lat.toFixed(6)+','+lng.toFixed(6) : 'N/A'}</div>
             </div>
             <div>
               <label style="font-size:10px; font-weight:800; color:var(--text-secondary); text-transform:uppercase; margin-bottom:8px; display:block;">Submitted At</label>
               <div style="font-size:13px; font-weight:600; color: var(--text-primary);">${formatTime(r.timestamp)}</div>
             </div>
          </div>

          <div class="card" style="height:300px; border-radius:12px; margin-top:20px; overflow: hidden; border: 1px solid var(--border);">
             <div id="detail-map" style="height:100%; width:100%;"></div>
          </div>
        </div>
      </div>

      <div style="background:var(--bg-primary); display:flex; flex-direction:column; padding:32px;">
        <div style="display:flex; justify-content:space-between; margin-bottom:32px; align-items: center;">
          <h3 style="font-size:14px; font-weight:800; text-transform:uppercase; color: var(--text-primary);">Management</h3>
          <button onclick="closeModal()" style="border:none; background:none; cursor:pointer; color:var(--text-secondary); font-weight: 600;">✕ CLOSE</button>
        </div>

        <div class="card" style="padding:20px; background:var(--surface); margin-bottom:24px; border: 1px solid var(--border);">
           <label style="font-size:10px; font-weight:800; color:var(--info); text-transform:uppercase; display:block; margin-bottom:12px;">Assigned Volunteers</label>
           <div style="display:flex; flex-direction:column; gap:8px;">
             ${assignedHtml}
           </div>
           <div style="margin-top:16px;">
             <select id="vol-select" style="width:100%; padding:10px; border-radius:8px; border:1px solid var(--border); background:var(--input-bg); color: var(--text-primary); font-size:12px; margin-bottom:8px;">
                <option value="">Select a volunteer...</option>
                ${available.map(v => `<option value="${v.id}">${esc(v.name)} [${v.volunteerId}]</option>`).join("")}
             </select>
             <button class="btn-primary" onclick="assignVolunteer()" style="width: 100%; padding:10px; font-size:12px;">Assign Volunteer</button>
           </div>
        </div>

        <div class="card" style="padding:20px; background:var(--surface); border: 1px solid var(--border);">
           <label style="font-size:10px; font-weight:800; color:var(--success); text-transform:uppercase; display:block; margin-bottom:12px;">Resolve Report</label>
           <div class="resolve-form">
              <label style="font-size:10px; color: var(--text-secondary);">Award Points</label>
              <input type="number" id="awarded-points" value="10" style="width:100%; padding:8px; border-radius:6px; border:1px solid var(--border); background: var(--input-bg); color: var(--text-primary); margin-bottom:12px;">
              <label style="font-size:10px; color: var(--text-secondary);">Resolution Note</label>
              <textarea id="resolve-note" placeholder="Enter note..." style="width: 100%; padding: 8px; border: 1px solid var(--border); background: var(--input-bg); color: var(--text-primary); border-radius: 6px; font-size:12px; min-height: 80px;"></textarea>
              <button class="btn-primary" onclick="resolveReport('${r.id}')" style="width: 100%; margin-top: 12px; background:var(--success);">Resolve Report</button>
           </div>
        </div>
      </div>
    </div>
  `;

  if (hasCoords) {
    const isDark = document.documentElement.classList.contains('dark-mode');
    const tileUrl = isDark
      ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
      : 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';

    setTimeout(() => {
      if (detailMapInstance) detailMapInstance.remove();
      detailMapInstance = L.map("detail-map").setView([lat, lng], 14);
      L.tileLayer(tileUrl, { attribution: '&copy; OpenStreetMap' }).addTo(detailMapInstance);
      L.circleMarker([lat, lng], { radius: 10, color: "white", fillColor: "#2563EB", fillOpacity: 0.8, weight: 2 }).addTo(detailMapInstance);
    }, 200);
  }
}

window.openReport = (id) => {
  const r = allReports.find(x => x.id === id);
  if (!r) return;
  activeReportId = id;
  renderModalContentOnly(r);
  document.getElementById("report-modal").style.display = "flex";
  previousFocus = document.activeElement;
};

window.closeModal = () => {
  document.getElementById("report-modal").style.display = "none";
  activeReportId = null;
  if (detailMapInstance) { detailMapInstance.remove(); detailMapInstance = null; }
  if (previousFocus) previousFocus.focus();
};

window.assignVolunteer = async () => {
  const volId = document.getElementById("vol-select").value;
  if (!volId) return showToast("Select a volunteer first");
  try {
    await updateDoc(doc(db, "reports", activeReportId), { assignedVolunteers: arrayUnion(volId) });
    logAdminAction("assign_volunteer", activeReportId, { volunteerId: volId });
    showToast("Volunteer assigned");
  } catch (e) { showToast(e.message); }
};

window.removeVolunteer = async (volId) => {
  try {
    await updateDoc(doc(db, "reports", activeReportId), { assignedVolunteers: arrayRemove(volId) });
    showToast("Volunteer removed");
  } catch (e) { showToast(e.message); }
};

window.resolveReport = async (id) => {
  const note = document.getElementById("resolve-note").value.trim();
  const pts = parseInt(document.getElementById("awarded-points").value) || 0;
  if (!confirm("Mark this report as resolved?")) return;
  try {
    const reportRef = doc(db, "reports", id);
    const snap = await getDoc(reportRef);
    const assigned = snap.data().assignedVolunteers || [];
    await updateDoc(reportRef, { status: "completed", resolvedAt: serverTimestamp(), resolutionNote: note });
    if (pts > 0 && assigned.length > 0) {
      await Promise.all(assigned.map(uid => updateDoc(doc(db, "users", uid), { points: increment(pts) })));
    }
    showToast("Report marked as resolved");
    renderReports();
  } catch (e) { showToast(e.message); }
};

function updateReportsBadge() {
  const active = allReports.filter(r => r.status !== "completed" && r.status !== "suspected_spam" && r.status !== "flagged").length;
  const badge = document.getElementById("reports-badge");
  if (badge) {
    badge.textContent = active;
    badge.style.display = active > 0 ? "inline" : "none";
  }
}
