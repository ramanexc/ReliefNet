import { db } from "./firebase-init.js";
import {
  collection,
  doc,
  updateDoc,
  arrayUnion,
  arrayRemove,
  orderBy,
  query,
  serverTimestamp,
  onSnapshot,
} from "https://www.gstatic.com/firebasejs/10.12.0/firebase-firestore.js";
import {
  typeIcon,
  urgencyBadge,
  statusBadge,
  formatTime,
  showToast,
  emptyRow,
  esc,
  renderPagination,
  exportToCSV,
  logAdminAction,
} from "./utils.js";
import { allVolunteers } from "./volunteers.js";

export let allReports = [];
let currentFilter = "all";
let searchQuery = "";
let currentPage = 1;
const itemsPerPage = 10;
let activeReportId = null;
let previousFocus = null; // for focus trapping
let unsubscribeReports = null;
let detailMapInstance = null; // Leaflet map inside report modal

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

        // If modal is open, dynamically re-render its dynamic elements
        if (activeReportId) {
          const activeRep = allReports.find((r) => r.id === activeReportId);
          if (activeRep) {
            renderModalContentOnly(activeRep);
          } else {
            window.closeModal();
          }
        }

        // Trigger overview update dynamically
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

// ─── UNSUBSCRIBE LISTENER ────────────────────────────────────
export function unsubReports() {
  if (unsubscribeReports) {
    unsubscribeReports();
    unsubscribeReports = null;
  }
}

// ─── RENDER TABLE ────────────────────────────────────────────
export function renderReports() {
  let filtered =
    currentFilter === "all"
      ? allReports
      : currentFilter === "completed"
        ? allReports.filter((r) => r.status === "completed")
        : currentFilter === "spam"
          ? allReports.filter((r) => r.status === "suspected_spam" || r.status === "flagged")
          : currentFilter === "active"
            ? allReports.filter((r) => r.status !== "completed" && r.status !== "suspected_spam" && r.status !== "flagged")
            : allReports.filter((r) => r.urgency === currentFilter);

  if (searchQuery) {
    filtered = filtered.filter(
      (r) =>
        (r.issueType || "").toLowerCase().includes(searchQuery) ||
        (r.description || "").toLowerCase().includes(searchQuery) ||
        (r.submittedBy || "").toLowerCase().includes(searchQuery),
    );
  }

  const totalItems = filtered.length;
  const totalPages = Math.max(1, Math.ceil(totalItems / itemsPerPage));
  if (currentPage > totalPages) currentPage = totalPages;

  const start = (currentPage - 1) * itemsPerPage;
  const paginated = filtered.slice(start, start + itemsPerPage);

  const tbody = document.getElementById("reports-body");
  if (paginated.length === 0) {
    tbody.innerHTML = emptyRow(6, "empty", "No reports found");
    renderPagination(
      "reports-pagination",
      currentPage,
      totalPages,
      "reportsPrevPage()",
      "reportsNextPage()",
    );
    return;
  }

  tbody.innerHTML = paginated
    .map(
      (r) => `
    <tr style="cursor:pointer" onclick="openReport('${r.id}')">
      <td>${typeIcon(r.issueType)} ${esc(r.issueType)}</td>
      <td class="desc-cell">${esc(r.description)}</td>
      <td>${urgencyBadge(r.urgency)}</td>
      <td>${statusBadge(r.status)}</td>
      <td style="font-size:12px;color:var(--gray-400)">${formatTime(r.timestamp)}</td>
      <td><span style="font-size:12px;color:var(--blue);font-weight:600">View →</span></td>
    </tr>
  `,
    )
    .join("");

  renderPagination(
    "reports-pagination",
    currentPage,
    totalPages,
    "reportsPrevPage()",
    "reportsNextPage()",
  );
}

// ─── FILTER ──────────────────────────────────────────────────
window.filterReports = (filter, btn) => {
  currentFilter = filter;
  currentPage = 1;
  document
    .querySelectorAll("#page-reports .filter-btn")
    .forEach((b) => b.classList.remove("active"));
  btn.classList.add("active");
  renderReports();
};

// ─── SEARCH / PAGINATION ACTIONS ─────────────────────────────
window.searchReports = (val) => {
  searchQuery = val.trim().toLowerCase();
  currentPage = 1;
  renderReports();
};

window.reportsPrevPage = () => {
  if (currentPage > 1) {
    currentPage--;
    renderReports();
  }
};

window.reportsNextPage = () => {
  let filtered =
    currentFilter === "all"
      ? allReports
      : currentFilter === "completed"
        ? allReports.filter((r) => r.status === "completed")
        : currentFilter === "spam"
          ? allReports.filter((r) => r.status === "suspected_spam" || r.status === "flagged")
          : currentFilter === "active"
            ? allReports.filter((r) => r.status !== "completed" && r.status !== "suspected_spam" && r.status !== "flagged")
            : allReports.filter((r) => r.urgency === currentFilter);

  if (searchQuery) {
    filtered = filtered.filter(
      (r) =>
        (r.issueType || "").toLowerCase().includes(searchQuery) ||
        (r.description || "").toLowerCase().includes(searchQuery) ||
        (r.submittedBy || "").toLowerCase().includes(searchQuery),
    );
  }
  const totalPages = Math.ceil(filtered.length / itemsPerPage);
  if (currentPage < totalPages) {
    currentPage++;
    renderReports();
  }
};

// ─── CSV DATA EXPORT ──────────────────────────────────────────
window.exportReports = () => {
  const headers = [
    "Report ID",
    "Type",
    "Description",
    "Urgency",
    "Status",
    "Submitted By",
    "Submitted At",
    "Assigned Volunteers",
    "Resolution Note",
    "Resolved At",
  ];
  const rows = allReports.map((r) => [
    r.id,
    r.issueType || "",
    r.description || "",
    r.urgency || "",
    r.status || "",
    r.submittedBy || "",
    r.timestamp?.toDate
      ? r.timestamp.toDate().toISOString()
      : r.timestamp || "",
    (r.assignedVolunteers || []).join("; "),
    r.resolutionNote || "",
    r.resolvedAt?.toDate
      ? r.resolvedAt.toDate().toISOString()
      : r.resolvedAt || "",
  ]);
  exportToCSV(
    `reliefnet_reports_${new Date().toISOString().split("T")[0]}.csv`,
    headers,
    rows,
  );
};

// ─── DYNAMIC MODAL REDRAW ────────────────────────────────────
function renderModalContentOnly(r) {
  const noteEl = document.getElementById("resolve-note");
  const savedNote = noteEl ? noteEl.value : "";

  const ai = r.aiSummary || {};
  const skills = ai.skillset_required || [];
  const solutions = ai.solutions || [];
  const assigned = r.assignedVolunteers || [];
  const cred = r.credibility || {};

  // Build assigned volunteers section
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
            <button onclick="removeVolunteer('${uid}')" title="Remove" style="margin-left: 6px;">✕</button>
          </div>
        `;
          })
          .join("");

  // Build volunteer dropdown (exclude already assigned)
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
        <button class="action-btn btn-resolve" onclick="assignVolunteer()" style="white-space:nowrap">Assign</button>
      </div>
    `;

  const activeId = document.activeElement ? document.activeElement.id : null;
  const lat = Number(r.lat);
  const lng = Number(r.lng);
  const hasCoords =
    !isNaN(lat) && !isNaN(lng) && r.lat !== undefined && r.lng !== undefined;

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

  const verificationHtml = r.verificationScore !== undefined ? `
    <div class="modal-section" style="border-left: 4px solid ${r.verificationScore >= 75 ? 'var(--green)' : r.verificationScore >= 50 ? 'var(--orange)' : 'var(--red)'}">
      <div class="modal-section-title" style="display:flex;justify-content:space-between;align-items:center">
        <span><svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"></path></svg> Verification Score</span>
        <span class="badge ${r.verificationScore >= 75 ? 'badge-approved' : r.verificationScore >= 50 ? 'badge-pending' : 'badge-rejected'}" style="font-size:11px">${r.verificationScore}% Complete</span>
      </div>
      <div style="margin-top:10px">
        <div style="background:var(--gray-200);border-radius:6px;height:8px;overflow:hidden;width:100%;margin-bottom:6px">
          <div style="background:${r.verificationScore >= 75 ? 'var(--green)' : r.verificationScore >= 50 ? 'var(--orange)' : 'var(--red)'};height:100%;width:${r.verificationScore}%"></div>
        </div>
        <div style="font-size:12px;color:var(--gray-500)">
          Calculated based on coordinate precision, description content, phone verification, and media upload completeness.
        </div>
      </div>
    </div>
  ` : '';

  const needsHtml = ((r.peopleAffected && r.peopleAffected !== 'Unknown') || (r.immediateNeeds && r.immediateNeeds.length > 0)) ? `
    <div class="modal-section">
      <div class="modal-section-title"><svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path><circle cx="9" cy="7" r="4"></circle><path d="M23 21v-2a4 4 0 0 0-3-3.87"></path><path d="M16 3.13a4 4 0 0 1 0 7.75"></path></svg> Impact & Urgent Needs</div>
      ${r.peopleAffected && r.peopleAffected !== 'Unknown' ? `
        <div style="font-size:13px;color:var(--gray-700);margin-bottom:8px">
          <strong>Estimated People Affected:</strong> ${esc(r.peopleAffected)}
        </div>
      ` : ''}
      ${r.immediateNeeds && r.immediateNeeds.length > 0 ? `
        <div style="font-size:11px;font-weight:700;color:var(--gray-400);text-transform:uppercase;letter-spacing:0.05em;margin-top:10px;margin-bottom:6px">Immediate Needs Checklist</div>
        <div style="display:flex;flex-wrap:wrap;gap:6px">
          ${r.immediateNeeds.map((need) => `<span style="background:var(--blue-light);color:var(--blue);border:1px solid rgba(37,99,235,0.15);border-radius:20px;padding:3px 10px;font-size:11px;font-weight:600">${esc(need)}</span>`).join('')}
        </div>
      ` : ''}
    </div>
  ` : '';

  const contactHtml = (r.allowContact && r.contactPhone) ? `
    <div class="modal-section">
      <div class="modal-section-title"><svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z"></path></svg> Contact Information</div>
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px">
        <div>
          <div style="font-size:10px;color:var(--gray-400);text-transform:uppercase">Contact Phone</div>
          <div style="font-size:13px;font-weight:600;margin-top:2px">
            <a href="tel:${esc(r.contactPhone)}" style="color:var(--blue);text-decoration:none">${esc(r.contactPhone)}</a>
          </div>
        </div>
        ${r.contactAltPhone ? `
          <div>
            <div style="font-size:10px;color:var(--gray-400);text-transform:uppercase">Alternative Phone</div>
            <div style="font-size:13px;font-weight:600;margin-top:2px">
              <a href="tel:${esc(r.contactAltPhone)}" style="color:var(--blue);text-decoration:none">${esc(r.contactAltPhone)}</a>
             </div>
          </div>
        ` : ''}
      </div>
    </div>
  ` : '';

  document.getElementById("modal-body").innerHTML = `
    <!-- HEADER -->
    <div style="display:flex;align-items:flex-start;justify-content:space-between;margin-bottom:20px">
      <div>
        <div style="display:flex;align-items:center;gap:10px;margin-bottom:6px">
          <span style="font-size:22px">${typeIcon(r.issueType)}</span>
          <h2 id="modal-title" style="font-size:20px;font-weight:700;color:var(--gray-900)">${esc(r.issueType) || "Report"}</h2>
          ${urgencyBadge(r.urgency)}
          ${statusBadge(r.status)}
        </div>
        <div style="font-size:12px;color:var(--gray-400);font-family:'DM Mono',monospace">ID: ${r.id}</div>
      </div>
      <button onclick="closeModal()" style="background:var(--gray-100);border:none;border-radius:8px;padding:6px 12px;cursor:pointer;font-size:18px;color:var(--gray-500)">✕</button>
    </div>

    ${lifeThreateningHtml}

    <div style="display:grid;grid-template-columns:1fr 1fr;gap:16px">

      <!-- LEFT COLUMN -->
      <div style="display:flex;flex-direction:column;gap:16px">

        <!-- Description -->
        <div class="modal-section">
          <div class="modal-section-title"><svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"></path><path d="M18.5 2.5a2.121 2.121 0 1 1 3 3L12 15l-4 1 1-4 9.5-9.5z"></path></svg> Description</div>
          <div style="font-size:14px;color:var(--gray-700);line-height:1.6">${esc(r.description)}</div>
        </div>

        <!-- Location & Mini Map -->
        <div class="modal-section">
          <div class="modal-section-title"><svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"></path><circle cx="12" cy="10" r="3"></circle></svg> Location</div>
          ${
            hasCoords
              ? `
            <div style="font-size:13px;color:var(--gray-600);margin-bottom:8px;display:flex;justify-content:space-between;align-items:center">
              <span>${lat.toFixed(6)}, ${lng.toFixed(6)}</span>
              ${r.gpsAccuracy !== undefined ? `
                <span style="font-size:11px;color:var(--gray-400)">Accuracy: ±${Number(r.gpsAccuracy).toFixed(1)}m</span>
              ` : ''}
            </div>
            ${r.landmark ? `
              <div style="font-size:13px;color:var(--gray-700);margin-bottom:10px;background:var(--gray-100);padding:6px 10px;border-radius:6px;border-left:3px solid var(--blue);font-style:italic">
                <strong>Landmark:</strong> ${esc(r.landmark)}
              </div>
            ` : ''}
            <a href="https://maps.google.com/?q=${lat},${lng}" target="_blank"
               style="font-size:12px;color:var(--blue);font-weight:600;text-decoration:none;display:inline-flex;align-items:center;gap:4px;margin-bottom:8px">
              <svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" style="width:12px;height:12px;"><polygon points="3 6 9 3 15 6 21 3 21 18 15 21 9 18 3 21"></polygon><line x1="9" y1="3" x2="9" y2="18"></line><line x1="15" y1="6" x2="15" y2="21"></line></svg> Open in Google Maps →
            </a>
            <div id="detail-map"></div>
          `
              : '<div style="color:var(--gray-400);font-size:13px">No location data</div>'
          }
        </div>

        ${needsHtml}

        ${contactHtml}

        <!-- Submitted by -->
        <div class="modal-section">
          <div class="modal-section-title"><svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"></path><circle cx="12" cy="7" r="4"></circle></svg> Submitted By</div>
          <div class="mono">${esc(r.submittedBy)}</div>
          <div style="font-size:12px;color:var(--gray-400);margin-top:4px">${formatTime(r.timestamp)}</div>
        </div>

        <!-- Resolution (if completed) -->
        ${
          r.status === "completed"
            ? `
        <div class="modal-section" style="border-color:var(--green);background:var(--green-light)">
          <div class="modal-section-title" style="color:var(--green)"><svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"></path><polyline points="22 4 12 14.01 9 11.01"></polyline></svg> Resolution</div>
          <div style="font-size:13px;color:var(--gray-700)">${esc(r.resolutionNote) || "No note provided"}</div>
          <div style="font-size:12px;color:var(--gray-400);margin-top:4px">Resolved: ${formatTime(r.resolvedAt)}</div>
        </div>
        `
            : ""
        }

        <!-- Media Previews -->
        <div class="modal-section">
          <div class="modal-section-title"><svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21.44 11.05l-9.19 9.19a6 6 0 0 1-8.49-8.49l9.19-9.19a4 4 0 0 1 5.66 5.66l-9.2 9.19a2 2 0 0 1-2.83-2.83l8.49-8.48"></path></svg> Media Previews</div>
          ${
            r.mediaUrls && r.mediaUrls.length > 0
              ? `<div class="media-previews-container">
                ${r.mediaUrls
                  .map((url) => {
                    const escapedUrl = esc(url);
                    const isImage =
                      /\.(jpg|jpeg|png|webp|gif)($|\?)/i.test(url) ||
                      (url.includes("alt=media") && !url.includes("video"));
                    const isVideo =
                      /\.(mp4|webm|ogg|mov)($|\?)/i.test(url) ||
                      url.includes("video");

                    if (isImage) {
                      return `
                      <a href="${escapedUrl}" target="_blank" class="media-preview-item" title="Open original image">
                        <img src="${escapedUrl}" class="media-preview-img" alt="Report Attachment">
                      </a>
                    `;
                    } else if (isVideo) {
                      return `
                      <div class="media-preview-item">
                        <video src="${escapedUrl}" class="media-preview-video" controls muted></video>
                      </div>
                    `;
                    } else {
                      return `
                      <a href="${escapedUrl}" target="_blank" class="media-preview-item media-preview-file" title="Download File">
                        <span><svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="width:24px;height:24px;color:var(--gray-400);"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path><polyline points="14 2 14 8 20 8"></polyline><line x1="16" y1="13" x2="8" y2="13"></line><line x1="16" y1="17" x2="8" y2="17"></line><polyline points="10 9 9 9 8 9"></polyline></svg></span>
                        <div style="font-size: 10px; padding: 2px;">Open Document</div>
                      </a>
                    `;
                    }
                  })
                  .join("")}
               </div>`
              : '<div style="color:var(--gray-400);font-size:13px">No media attached</div>'
          }
        </div>

      </div>

      <!-- RIGHT COLUMN -->
      <div style="display:flex;flex-direction:column;gap:16px">

        ${verificationHtml}

        <!-- Credibility Engine -->
        ${cred.score !== undefined ? `
        <div class="modal-section" style="border-left: 4px solid ${cred.score >= 70 ? 'var(--green)' : 'var(--red)'}">
          <div class="modal-section-title" style="display:flex;justify-content:space-between;align-items:center">
            <span><svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"></path></svg> Credibility Engine</span>
            <span class="badge ${cred.score >= 70 ? 'badge-green' : 'badge-red'}" style="font-size:14px">${cred.score}% Match</span>
          </div>
          <div style="margin-top:10px">
            <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px">
              <div>
                <div style="font-size:10px;color:var(--gray-400);text-transform:uppercase">Spam Probability</div>
                <div style="font-size:13px;font-weight:600">${cred.spamProbability}%</div>
              </div>
              <div>
                <div style="font-size:10px;color:var(--gray-400);text-transform:uppercase">AI Verdict</div>
                <div style="font-size:13px;font-weight:600">${esc(cred.status)}</div>
              </div>
            </div>
            <div style="margin-top:12px;font-size:12px;color:var(--gray-600);background:var(--gray-100);padding:8px;border-radius:6px;font-style:italic">
              "${esc(cred.reason)}"
            </div>
          </div>
        </div>
        ` : ''}

        <!-- AI Summary -->
        <div class="modal-section" style="background:var(--blue-light);border-color:var(--blue)">
          <div class="modal-section-title" style="color:var(--blue)"><svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"></polygon></svg> AI Analysis <span style="font-size:10px;font-weight:400;opacity:0.7">Powered by Gemini</span></div>
          <div style="font-size:13px;color:var(--gray-700);font-style:italic;margin-bottom:12px;line-height:1.5">${esc(ai.summary)}</div>
          <div style="display:flex;gap:16px;margin-bottom:12px">
            <div>
              <div style="font-size:10px;font-weight:700;color:var(--gray-400);text-transform:uppercase;letter-spacing:0.05em;margin-bottom:3px">Action Priority</div>
              <div style="font-size:13px;font-weight:600;color:var(--blue)">${esc(ai.action_priority)}</div>
            </div>
            <div>
              <div style="font-size:10px;font-weight:700;color:var(--gray-400);text-transform:uppercase;letter-spacing:0.05em;margin-bottom:3px">Est. Affected</div>
              <div style="font-size:13px;font-weight:600;color:var(--gray-700)">${esc(ai.estimated_people_affected)}</div>
            </div>
          </div>
          ${
            skills.length > 0
              ? `
            <div style="margin-bottom:10px">
              <div style="font-size:10px;font-weight:700;color:var(--gray-400);text-transform:uppercase;letter-spacing:0.05em;margin-bottom:6px">Skills Required</div>
              <div style="display:flex;flex-wrap:wrap;gap:6px">
                ${skills.map((s) => `<span style="background:var(--card-bg);color:var(--blue);border:1px solid var(--blue);border-radius:20px;padding:2px 10px;font-size:11px;font-weight:600">${esc(s)}</span>`).join("")}
              </div>
            </div>
          `
              : ""
          }
          ${
            solutions.length > 0
              ? `
            <div>
              <div style="font-size:10px;font-weight:700;color:var(--gray-400);text-transform:uppercase;letter-spacing:0.05em;margin-bottom:6px">Suggested Solutions</div>
              ${solutions
                .map(
                  (s, i) => `
                <div style="display:flex;gap:8px;margin-bottom:6px;font-size:12px;color:var(--gray-700)">
                  <span style="background:var(--blue);color:white;border-radius:50%;width:18px;height:18px;display:flex;align-items:center;justify-content:center;font-size:10px;font-weight:700;flex-shrink:0">${i + 1}</span>
                  <span>${esc(s)}</span>
                </div>
              `,
                )
                .join("")}
            </div>
          `
              : ""
          }
        </div>

        <!-- Volunteer Assignment -->
        <div class="modal-section">
          <div class="modal-section-title"><svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path><circle cx="9" cy="7" r="4"></circle><path d="M23 21v-2a4 4 0 0 0-3-3.87"></path><path d="M16 3.13a4 4 0 0 1 0 7.75"></path></svg> Assigned Volunteers</div>
          <div id="assigned-volunteers-list" style="display:flex;flex-wrap:wrap;gap:8px;margin-bottom:8px">
            ${assignedHtml}
          </div>
          <div style="font-size:11px;font-weight:700;color:var(--gray-400);text-transform:uppercase;letter-spacing:0.05em;margin-top:12px">Add Volunteer</div>
          ${dropdownHtml}
        </div>

        <!-- Quick Actions -->
        <div class="modal-section">
          <div class="modal-section-title"><svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"></polygon></svg> Quick Actions</div>
          <div style="display:flex;flex-direction:column;gap:8px">
            ${
              r.status !== "completed"
                ? `
              <div class="resolve-form">
                <label for="resolve-note">Resolution Note (optional)</label>
                <textarea id="resolve-note" placeholder="Describe how this was resolved..."></textarea>
                <div style="display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-top:8px">
                  <button class="action-btn btn-resolve" id="resolve-btn" onclick="resolveReport('${r.id}')" style="padding:10px;font-size:13px;display:inline-flex;align-items:center;justify-content:center;gap:6px;">
                    <svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" style="width:14px;height:14px;"><polyline points="20 6 9 17 4 12"></polyline></svg> Resolved
                  </button>
                  ${r.status === 'suspected_spam' || r.status === 'flagged' ? `
                    <button class="action-btn btn-approve" onclick="updateReportStatus('${r.id}', 'unassigned')" style="padding:10px;font-size:13px;display:inline-flex;align-items:center;justify-content:center;gap:6px;">
                      <svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" style="width:14px;height:14px;"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"></path><polyline points="22 4 12 14.01 9 11.01"></polyline></svg> Verify
                    </button>
                  ` : `
                    <button class="action-btn btn-reject" onclick="updateReportStatus('${r.id}', 'suspected_spam')" style="padding:10px;font-size:13px;display:inline-flex;align-items:center;justify-content:center;gap:6px;">
                      <svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" style="width:14px;height:14px;"><circle cx="12" cy="12" r="10"></circle><line x1="4.93" y1="4.93" x2="19.07" y2="19.07"></line></svg> Mark Spam
                    </button>
                  `}
                </div>
              </div>
            `
                : `<div style="font-size:13px;color:var(--green);font-weight:600;display:inline-flex;align-items:center;gap:6px;"><svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" style="width:16px;height:16px;color:var(--green);"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"></path><polyline points="22 4 12 14.01 9 11.01"></polyline></svg> This report has been resolved</div>`
            }
          </div>
        </div>

      </div>
    </div>
  `;

  // Restore note text if applicable
  const newNoteEl = document.getElementById("resolve-note");
  if (newNoteEl && savedNote) {
    newNoteEl.value = savedNote;
  }

  // Restore focus if element still exists
  if (activeId) {
    const el = document.getElementById(activeId);
    if (el) el.focus();
  }

  // Re-draw/update Leaflet Map
  if (hasCoords) {
    try {
      if (typeof L !== "undefined") {
        setTimeout(() => {
          const container = document.getElementById("detail-map");
          if (container) {
            if (detailMapInstance) {
              detailMapInstance.remove();
              detailMapInstance = null;
            }
            detailMapInstance = L.map("detail-map").setView([lat, lng], 14);
            L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
              maxZoom: 19,
              attribution: "© OpenStreetMap",
            }).addTo(detailMapInstance);
            const markerColor =
              r.urgency === "High"
                ? "#EF4444"
                : r.urgency === "Medium"
                  ? "#F97316"
                  : "#22C55E";
            L.circleMarker([lat, lng], {
              radius: 8,
              fillColor: markerColor,
              color: "#ffffff",
              weight: 2,
              opacity: 1,
              fillOpacity: 0.8,
            }).addTo(detailMapInstance);
          }
        }, 50);
      } else {
        console.warn("Leaflet mini-map skipped: L is not defined.");
      }
    } catch (err) {
      console.error("Failed to initialize detail mini-map:", err);
    }
  }
}

// ─── OPEN REPORT MODAL ───────────────────────────────────────
window.openReport = (id) => {
  const r = allReports.find((x) => x.id === id);
  if (!r) return;
  activeReportId = id;

  renderModalContentOnly(r);

  const modal = document.getElementById("report-modal");
  modal.style.display = "flex";

  // Focus management: save previous focus and move into modal
  previousFocus = document.activeElement;
  const closeBtn = modal.querySelector('button[onclick="closeModal()"]');
  if (closeBtn) closeBtn.focus();
};

// ─── CLOSE MODAL ─────────────────────────────────────────
window.closeModal = () => {
  document.getElementById("report-modal").style.display = "none";
  activeReportId = null;
  if (detailMapInstance) {
    detailMapInstance.remove();
    detailMapInstance = null;
  }
  // Restore focus to the element that opened the modal
  if (previousFocus) {
    previousFocus.focus();
    previousFocus = null;
  }
};

// Close on backdrop click
document.getElementById("report-modal").addEventListener("click", (e) => {
  if (e.target.id === "report-modal") window.closeModal();
});

// Escape key + focus trap
document.addEventListener("keydown", (e) => {
  if (!activeReportId) return;
  if (e.key === "Escape") {
    const volModal = document.getElementById("volunteer-modal");
    if (volModal && volModal.style.display === "flex") return;
    window.closeModal();
    return;
  }
  if (e.key === "Tab") {
    const modal = document.getElementById("report-modal");
    const focusable = modal.querySelectorAll(
      'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])',
    );
    if (focusable.length === 0) return;
    const first = focusable[0];
    const last = focusable[focusable.length - 1];
    if (e.shiftKey) {
      if (document.activeElement === first) {
        e.preventDefault();
        last.focus();
      }
    } else {
      if (document.activeElement === last) {
        e.preventDefault();
        first.focus();
      }
    }
  }
});

// ─── ASSIGN VOLUNTEER ────────────────────────────────────────
window.assignVolunteer = async () => {
  const select = document.getElementById("vol-select");
  const volId = select.value;
  if (!volId) {
    showToast("Select a volunteer first");
    return;
  }
  try {
    await updateDoc(doc(db, "reports", activeReportId), {
      assignedVolunteers: arrayUnion(volId),
    });
    // Log action
    logAdminAction("assign_volunteer", activeReportId, { volunteerId: volId });

    const r = allReports.find((x) => x.id === activeReportId);
    if (r) {
      r.assignedVolunteers = r.assignedVolunteers || [];
      if (!r.assignedVolunteers.includes(volId)) {
        r.assignedVolunteers.push(volId);
      }
    }
    showToast("Volunteer assigned");
  } catch (e) {
    showToast("Error: " + e.message);
  }
};

// ─── REMOVE VOLUNTEER ────────────────────────────────────────
window.removeVolunteer = async (volId) => {
  try {
    await updateDoc(doc(db, "reports", activeReportId), {
      assignedVolunteers: arrayRemove(volId),
    });
    // Log action
    logAdminAction("remove_volunteer", activeReportId, { volunteerId: volId });

    const r = allReports.find((x) => x.id === activeReportId);
    if (r)
      r.assignedVolunteers = (r.assignedVolunteers || []).filter(
        (v) => v !== volId,
      );
    showToast("Volunteer removed");
  } catch (e) {
    showToast("Error: " + e.message);
  }
};

// ─── RESOLVE ─────────────────────────────────────────────────
window.resolveReport = async (id) => {
  if (!confirm("Mark this report as resolved? This action cannot be undone."))
    return;
  const btn = document.getElementById("resolve-btn");
  const noteEl = document.getElementById("resolve-note");
  const note = noteEl ? noteEl.value.trim() : "";
  if (btn) {
    btn.disabled = true;
    btn.innerHTML = "Resolving...";
  }
  try {
    const updateData = {
      status: "completed",
      resolvedAt: serverTimestamp(),
    };
    if (note) updateData.resolutionNote = note;
    await updateDoc(doc(db, "reports", id), updateData);

    // Log action
    logAdminAction("resolve_report", id, { resolutionNote: note });

    const r = allReports.find((x) => x.id === id);
    if (r) {
      r.status = "completed";
      if (note) r.resolutionNote = note;
    }
    renderReports();
    updateReportsBadge();
    showToast("Report marked as resolved");
  } catch (e) {
    if (btn) {
      btn.disabled = false;
      btn.innerHTML = `<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" style="width:14px;height:14px;"><polyline points="20 6 9 17 4 12"></polyline></svg> Mark as Resolved`;
    }
    showToast("Error: " + e.message);
  }
};

// ─── UPDATE STATUS (SPAM/VERIFY) ────────────────────────────
window.updateReportStatus = async (id, newStatus) => {
  const confirmMsg = newStatus === 'suspected_spam'
    ? "Mark this report as SPAM? It will be hidden from volunteers."
    : "Verify this report? It will be visible to volunteers.";

  if (!confirm(confirmMsg)) return;

  try {
    await updateDoc(doc(db, "reports", id), { status: newStatus });

    // Log action
    logAdminAction("update_report_status", id, { status: newStatus });

    const r = allReports.find((x) => x.id === id);
    if (r) r.status = newStatus;

    renderReports();
    updateReportsBadge();
    showToast(newStatus === 'suspected_spam' ? "Report marked as spam" : "Report verified");
  } catch (e) {
    showToast("Error: " + e.message);
  }
};

// ─── REPORTS BADGE ───────────────────────────────────────────
function updateReportsBadge() {
  const active = allReports.filter((r) => r.status !== "completed" && r.status !== "suspected_spam" && r.status !== "flagged").length;
  const badge = document.getElementById("reports-badge");
  if (badge) {
    if (active > 0) {
      badge.textContent = active;
      badge.style.display = "inline";
    } else {
      badge.style.display = "none";
    }
  }
}
