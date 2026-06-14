import { db } from "./firebase-init.js";
import {
  collection,
  doc,
  updateDoc,
  increment,
  arrayUnion,
  arrayRemove,
  orderBy,
  query,
  serverTimestamp,
  onSnapshot,
  getDoc,
} from "https://www.gstatic.com/firebasejs/10.12.0/firebase-firestore.js";
import {
  typeIcon,
  urgencyBadge,
  statusBadge,
  formatTime,
  showToast,
  emptyRow,
  esc,
  exportToCSV,
  logAdminAction,
} from "./utils.js";
import { allVolunteers } from "./volunteers.js";

export let allReports = [];
let searchQuery = "";
let selectedType = "all";
let activeReportsView = 'all'; // 'all', 'active', 'resolved', 'spam'
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
          if (activeRep) {
            renderModalContentOnly(activeRep);
          } else {
            window.closeModal();
          }
        }

        import("./overview.js").then((m) => m.renderOverview());
        resolve();
      },
      (err) => {
        console.error("Reports subscription error:", err);
        reject(err);
      },
    );
  });
}

export function unsubReports() {
  if (unsubscribeReports) {
    unsubscribeReports();
    unsubscribeReports = null;
  }
}

function updateHubStats() {
  const activeCount = allReports.filter(r => r.status !== 'completed' && r.status !== 'suspected_spam' && r.status !== 'flagged').length;
  const resolvedCount = allReports.filter(r => r.status === 'completed').length;
  const spamCount = allReports.filter(r => r.status === 'suspected_spam' || r.status === 'flagged').length;
  const totalCount = allReports.length;

  const activeStatEl = document.getElementById('hub-stats-active');
  const resolvedStatEl = document.getElementById('hub-stats-resolved');
  const allStatEl = document.getElementById('hub-stats-all');
  const spamNavEl = document.getElementById('hub-stats-spam-nav');

  if (activeStatEl) activeStatEl.textContent = activeCount;
  if (resolvedStatEl) resolvedStatEl.textContent = resolvedCount;
  if (allStatEl) allStatEl.textContent = totalCount;
  if (spamNavEl) spamNavEl.textContent = spamCount;
}

// ─── NAVIGATION & FILTERING ──────────────────────────────────
window.openReportsView = (view) => {
  activeReportsView = view;

  document.querySelectorAll('.reports-nav-column .card:first-child .reports-nav-item').forEach(btn => btn.classList.remove('active'));
  const activeNavBtn = document.getElementById(`nav-reports-${view}`);
  if (activeNavBtn) activeNavBtn.classList.add('active');

  const spamToggle = document.getElementById('show-spam-toggle');
  if (view === 'spam' && spamToggle) {
    spamToggle.checked = true;
  }

  renderReports();

  const navBtn = document.querySelector(`.sidebar-nav button[onclick*="'reports-list'"]`);
  window.showPage('reports-list', navBtn);
};

window.filterByType = (type) => {
  selectedType = type;

  document.querySelectorAll('.reports-nav-column .card:nth-child(2) .reports-nav-item').forEach(btn => btn.classList.remove('active'));

  // Find button by its onclick content to ensure exact match with types containing special chars
  const typeButtons = document.querySelectorAll('.reports-nav-column .card:nth-child(2) .reports-nav-item');
  typeButtons.forEach(btn => {
    if (btn.getAttribute('onclick')?.includes(`'${type}'`)) {
      btn.classList.add('active');
    }
  });

  renderReports();
};

window.searchReports = (val) => {
  searchQuery = val.trim().toLowerCase();
  renderReports();
};

window.toggleSpamView = () => {
  renderReports();
};

// ─── RENDER TABLES ───────────────────────────────────────────
export function renderReports() {
  let filtered = allReports;

  if (searchQuery) {
    filtered = filtered.filter(
      (r) =>
        (r.issueType || "").toLowerCase().includes(searchQuery) ||
        (r.description || "").toLowerCase().includes(searchQuery) ||
        (r.id || "").toLowerCase().includes(searchQuery) ||
        (r.submittedBy || "").toLowerCase().includes(searchQuery),
    );
  }

  if (selectedType !== "all") {
    filtered = filtered.filter(r => (r.issueType || "").toLowerCase() === selectedType.toLowerCase());
  }

  const showSpam = document.getElementById('show-spam-toggle')?.checked || false;

  let activeList = [];
  let resolvedList = [];

  if (activeReportsView === 'active') {
    activeList = filtered.filter(r => r.status !== "completed" && (showSpam || (r.status !== 'suspected_spam' && r.status !== 'flagged')));
  } else if (activeReportsView === 'resolved') {
    resolvedList = filtered.filter(r => r.status === "completed");
  } else if (activeReportsView === 'spam') {
    activeList = filtered.filter(r => r.status === 'suspected_spam' || r.status === 'flagged');
  } else {
    activeList = filtered.filter(r => r.status !== "completed" && (showSpam || (r.status !== 'suspected_spam' && r.status !== 'flagged')));
    resolvedList = filtered.filter(r => r.status === "completed");
  }

  const priorityMap = { High: 0, Medium: 1, Low: 2 };
  const sortByPriority = (a, b) => {
    const pa = priorityMap[a.urgency] ?? 3;
    const pb = priorityMap[b.urgency] ?? 3;
    if (pa !== pb) return pa - pb;
    return (b.timestamp?.seconds ?? 0) - (a.timestamp?.seconds ?? 0);
  };

  activeList.sort(sortByPriority);
  resolvedList.sort(sortByPriority);

  renderReportsColumn("reports-active-body", activeList);
  renderReportsColumn("reports-resolved-body", resolvedList);

  const activeTbody = document.getElementById('reports-active-body');
  const resolvedTbody = document.getElementById('reports-resolved-body');

  if (activeTbody && resolvedTbody) {
    const activeCol = activeTbody.closest('.card');
    const resolvedCol = resolvedTbody.closest('.card');

    if (activeCol && resolvedCol) {
      if (activeReportsView === 'resolved') {
        activeCol.style.display = 'none';
        resolvedCol.style.display = 'block';
      } else if (activeReportsView === 'active' || activeReportsView === 'spam') {
        activeCol.style.display = 'block';
        resolvedCol.style.display = 'none';
      } else {
        activeCol.style.display = 'block';
        resolvedCol.style.display = 'block';
      }
    }
  }
}

function renderReportsColumn(containerId, reports) {
  const tbody = document.getElementById(containerId);
  if (!tbody) return;

  if (reports.length === 0) {
    tbody.innerHTML = emptyRow(3, "empty", "No reports found");
    return;
  }

  tbody.innerHTML = reports
    .map(
      (r) => {
        const isSpam = r.status === "suspected_spam" || r.status === "flagged";
        return `
    <tr onclick="window.openReport('${r.id}')" style="${isSpam ? 'background: var(--red-light);' : ''}">
      <td>
        <div style="font-weight:600; font-size:13px; color:var(--gray-900); display:flex; align-items:center; gap:6px;">
          ${typeIcon(r.issueType)} ${esc(r.issueType)}
          ${isSpam ? '<span style="background:var(--red); color:white; font-size:8px; padding:1px 4px; border-radius:4px; font-weight:bold;">SPAM</span>' : ''}
        </div>
        <div style="font-size:11px; color:var(--gray-400); font-family:'DM Mono',monospace; margin-top:2px;">ID: ${r.id.substring(0,8)}...</div>
        <div style="font-size:11px; color:var(--gray-600); margin-top:4px; white-space: normal; line-height: 1.3;">${esc(r.description).substring(0, 80)}${r.description?.length > 80 ? '...' : ''}</div>
      </td>
      <td style="font-size:11px; color:var(--gray-500); line-height:1.2;">
        ${formatTime(r.timestamp).replace(', ', '<br>')}
      </td>
      <td>
        <button class="action-btn btn-resolve" style="padding:4px 8px; font-size:10px;">View</button>
      </td>
    </tr>
  `;
      }
    )
    .join("");
}

// ─── REPORT MODAL ───────────────────────────────────────────
window.openReport = (id) => {
  const r = allReports.find((x) => x.id === id);
  if (!r) return;
  activeReportId = id;

  renderModalContentOnly(r);

  const modal = document.getElementById("report-modal");
  modal.style.display = "flex";

  previousFocus = document.activeElement;
  const closeBtn = modal.querySelector('button[onclick="closeModal()"]');
  if (closeBtn) closeBtn.focus();
};

window.closeModal = () => {
  document.getElementById("report-modal").style.display = "none";
  activeReportId = null;
  if (detailMapInstance) {
    detailMapInstance.remove();
    detailMapInstance = null;
  }
  if (previousFocus) {
    previousFocus.focus();
    previousFocus = null;
  }
};

function renderModalContentOnly(r) {
  const ai = r.aiSummary || r.ai_analysis || {};
  const skills = ai.skillset_required || [];
  const solutions = ai.solutions || [];
  const assigned = r.assignedVolunteers || [];
  const cred = r.credibility || {};

  const assignedHtml =
    assigned.length === 0
      ? `<div style="color:var(--gray-400);font-size:13px">No volunteers assigned yet</div>`
      : assigned
          .map((uid) => {
            const v = allVolunteers.find((x) => x.id === uid);
            const name = v ? esc(v.name || v.username || uid) : esc(uid);
            return `
          <div class="assigned-vol-chip">
            <button class="volunteer-link" onclick="window.openVolunteerProfile('${uid}')" style="color:var(--blue);font-weight:600;display:inline-flex;align-items:center;gap:4px;"><svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="width:12px;height:12px;"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"></path><circle cx="12" cy="7" r="4"></circle></svg>${name}</button>
            <button onclick="window.removeVolunteer('${uid}')" title="Remove" style="margin-left: 6px;">✕</button>
          </div>
        `;
          })
          .join("");

  const available = allVolunteers.filter((v) => !assigned.includes(v.id));
  const dropdownHtml =
    available.length === 0
      ? `<div style="color:var(--gray-400);font-size:13px;padding:8px 0">All volunteers already assigned</div>`
      : `
      <div style="display:flex;gap:8px;margin-top:10px">
        <select id="vol-select" style="flex:1;padding:8px 12px;border:1.5px solid var(--gray-200);border-radius:8px;font-size:13px;font-family:'DM Sans',sans-serif;color:var(--gray-700);outline:none">
          <option value="">Select a volunteer...</option>
          ${available.map((v) => `<option value="${v.id}">${esc(v.name || v.username)} — ${esc(v.volunteerId)}</option>`).join("")}
        </select>
        <button class="action-btn btn-resolve" onclick="window.assignVolunteer()" style="white-space:nowrap">Assign</button>
      </div>
    `;

  const lat = Number(r.lat);
  const lng = Number(r.lng);
  const hasCoords = !isNaN(lat) && !isNaN(lng) && r.lat !== undefined && r.lng !== undefined;

  const lifeThreateningHtml = r.isLifeThreatening ? `
    <div style="background:var(--red-light);border:1.5px solid var(--red);border-radius:10px;padding:12px;margin-bottom:16px;display:flex;align-items:flex-start;gap:10px;">
      <svg class="icon" viewBox="0 0 24 24" fill="none" stroke="var(--red)" stroke-width="2.2" style="width:20px;height:20px;flex-shrink:0"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"></path><line x1="12" y1="9" x2="12" y2="13"></line><line x1="12" y1="17" x2="12.01" y2="17"></line></svg>
      <div>
        <div style="color:var(--red);font-weight:700;font-size:14px;margin-bottom:2px">IMMEDIATE LIFE-THREATENING EMERGENCY</div>
        <div style="color:var(--gray-700);font-size:12px">
          <strong>Emergency Scenarios:</strong> ${(r.lifeThreateningScenarios || []).join(', ') || 'General immediate risk'}
        </div>
      </div>
    </div>
  ` : '';

  document.getElementById("modal-body").innerHTML = `
    <div style="display:flex;align-items:flex-start;justify-content:space-between;margin-bottom:20px">
      <div>
        <div style="display:flex;align-items:center;gap:10px;margin-bottom:6px">
          <span style="font-size:22px">${typeIcon(r.issueType)}</span>
          <h2 id="modal-title" style="font-size:20px;font-weight:700;color:var(--gray-900)">${esc(r.issueType)}</h2>
          ${urgencyBadge(r.urgency)}
          ${statusBadge(r.status)}
        </div>
        <div style="font-size:12px;color:var(--gray-400);font-family:'DM Mono',monospace">ID: ${r.id}</div>
      </div>
      <button onclick="window.closeModal()" style="background:var(--gray-100);border:none;border-radius:8px;padding:6px 12px;cursor:pointer;font-size:18px;color:var(--gray-500)">✕</button>
    </div>

    ${lifeThreateningHtml}

    <div style="display:grid;grid-template-columns:1fr 1fr;gap:16px">
      <div style="display:flex;flex-direction:column;gap:16px">
        <div class="modal-section">
          <div class="modal-section-title">Description</div>
          <div style="font-size:14px;color:var(--gray-700);line-height:1.6">${esc(r.description)}</div>
        </div>

        <div class="modal-section">
          <div class="modal-section-title">Location</div>
          ${hasCoords ? `
            <div style="font-size:13px;color:var(--gray-600);margin-bottom:8px;">${lat.toFixed(6)}, ${lng.toFixed(6)}</div>
            <div id="detail-map"></div>
          ` : '<div style="color:var(--gray-400);font-size:13px">No location data</div>'}
        </div>

        <div class="modal-section">
          <div class="modal-section-title">Submitted By</div>
          <div class="mono">${esc(r.submittedBy)}</div>
          <div style="font-size:12px;color:var(--gray-400);margin-top:4px">${formatTime(r.timestamp)}</div>
        </div>
      </div>

      <div style="display:flex;flex-direction:column;gap:16px">
        <div class="modal-section" style="background:var(--blue-light);border-color:var(--blue)">
          <div class="modal-section-title" style="color:var(--blue)">AI Analysis</div>
          <div style="font-size:13px;color:var(--gray-700);font-style:italic;margin-bottom:12px;">${esc(ai.summary || "No AI summary available")}</div>
        </div>

        <div class="modal-section">
          <div class="modal-section-title">Assigned Volunteers</div>
          <div id="assigned-volunteers-list" style="display:flex;flex-wrap:wrap;gap:8px;margin-bottom:8px">
            ${assignedHtml}
          </div>
          ${dropdownHtml}
        </div>

        <div class="modal-section">
          <div class="modal-section-title">Quick Actions</div>
          ${r.status !== "completed" ? `
            <div class="resolve-form">
              <label>Award Points</label>
              <input type="number" id="awarded-points" value="10" min="0" max="100">
              <textarea id="resolve-note" placeholder="Resolution Note..."></textarea>
              <button class="btn-primary" onclick="window.resolveReport('${r.id}')">Mark Resolved</button>
            </div>
          ` : `<div style="color:var(--green);font-weight:600;">Report Resolved</div>`}
        </div>
      </div>
    </div>
  `;

  if (hasCoords) {
    setTimeout(() => {
      if (detailMapInstance) detailMapInstance.remove();
      detailMapInstance = L.map("detail-map").setView([lat, lng], 14);
      L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png").addTo(detailMapInstance);
      L.circleMarker([lat, lng], { radius: 8, fillColor: "#2563EB", color: "#fff", weight: 2, fillOpacity: 0.8 }).addTo(detailMapInstance);
    }, 100);
  }
}

// ─── ACTIONS ─────────────────────────────────────────────────
window.assignVolunteer = async () => {
  const volId = document.getElementById("vol-select")?.value;
  if (!volId) return showToast("Select a volunteer");
  try {
    await updateDoc(doc(db, "reports", activeReportId), { assignedVolunteers: arrayUnion(volId) });
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
  const note = document.getElementById("resolve-note")?.value.trim();
  const points = parseInt(document.getElementById("awarded-points")?.value) || 0;
  try {
    const reportRef = doc(db, "reports", id);
    const snap = await getDoc(reportRef);
    const assigned = snap.data()?.assignedVolunteers || [];

    await updateDoc(reportRef, { status: "completed", resolvedAt: serverTimestamp(), resolutionNote: note });
    if (points > 0) {
      await Promise.all(assigned.map(uid => updateDoc(doc(db, "users", uid), { points: increment(points) })));
    }
    showToast("Report resolved");
  } catch (e) { showToast(e.message); }
};

window.updateReportStatus = async (id, newStatus) => {
  try {
    await updateDoc(doc(db, "reports", id), { status: newStatus });
    showToast("Status updated");
  } catch (e) { showToast(e.message); }
};

function updateReportsBadge() {
  const active = allReports.filter((r) => r.status !== "completed" && r.status !== "suspected_spam" && r.status !== "flagged").length;
  const badge = document.getElementById("reports-badge");
  if (badge) {
    badge.textContent = active;
    badge.style.display = active > 0 ? "inline" : "none";
  }
}
