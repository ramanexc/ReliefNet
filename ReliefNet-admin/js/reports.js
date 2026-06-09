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
        : currentFilter === "active"
          ? allReports.filter((r) => r.status !== "completed")
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
            <div style="font-size:13px;color:var(--gray-600);margin-bottom:8px">
              ${lat.toFixed(6)}, ${lng.toFixed(6)}
            </div>
            <a href="https://maps.google.com/?q=${lat},${lng}" target="_blank"
               style="font-size:12px;color:var(--blue);font-weight:600;text-decoration:none;display:inline-flex;align-items:center;gap:4px;">
              <svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" style="width:12px;height:12px;"><polygon points="3 6 9 3 15 6 21 3 21 18 15 21 9 18 3 21"></polygon><line x1="9" y1="3" x2="9" y2="18"></line><line x1="15" y1="6" x2="15" y2="21"></line></svg> Open in Google Maps →
            </a>
            <div id="detail-map"></div>
          `
              : '<div style="color:var(--gray-400);font-size:13px">No location data</div>'
          }
        </div>

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
                <button class="action-btn btn-resolve" id="resolve-btn" onclick="resolveReport('${r.id}')" style="width:100%;padding:10px;font-size:13px;display:inline-flex;align-items:center;justify-content:center;gap:6px;">
                  <svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" style="width:14px;height:14px;"><polyline points="20 6 9 17 4 12"></polyline></svg> Mark as Resolved
                </button>
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

// ─── REPORTS BADGE ───────────────────────────────────────────
function updateReportsBadge() {
  const active = allReports.filter((r) => r.status !== "completed").length;
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
