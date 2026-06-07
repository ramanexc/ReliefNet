import { loadReports, allReports } from "./reports.js";
import { loadApplications, allApps } from "./applications.js";
import { loadVolunteers } from "./volunteers.js";
import { typeIcon, urgencyBadge, statusBadge, formatTime, emptyRow } from "./utils.js";

export async function loadAll() {
  await Promise.all([loadReports(), loadApplications(), loadVolunteers()]);
  renderOverview();
}

export function renderOverview() {
  const total       = allReports.length;
  const active      = allReports.filter(r => r.status !== 'completed').length;
  const resolved    = allReports.filter(r => r.status === 'completed').length;
  const pendingApps = allApps.filter(a => a.status === 'pending').length;

  document.getElementById('stat-total').textContent       = total;
  document.getElementById('stat-active').textContent      = active;
  document.getElementById('stat-resolved').textContent    = resolved;
  document.getElementById('stat-pending-apps').textContent = pendingApps;

  // Recent 5 reports
  const recent = allReports.slice(0, 5);
  const tbody = document.getElementById('overview-reports-body');
  if (recent.length === 0) {
    tbody.innerHTML = emptyRow(4, '📭', 'No reports yet');
  } else {
    tbody.innerHTML = recent.map(r => `
      <tr>
        <td>${typeIcon(r.issueType)} ${r.issueType || '—'}</td>
        <td>${urgencyBadge(r.urgency)}</td>
        <td>${statusBadge(r.status)}</td>
        <td style="font-size:12px;color:var(--gray-400)">${formatTime(r.timestamp)}</td>
      </tr>
    `).join('');
  }

  // Category breakdown
  const cats = {};
  allReports.forEach(r => { cats[r.issueType || 'Other'] = (cats[r.issueType || 'Other'] || 0) + 1; });
  const catEl = document.getElementById('category-breakdown');
  if (total === 0) {
    catEl.innerHTML = '<div class="empty"><div class="empty-icon">📊</div><div class="empty-text">No data yet</div></div>';
    return;
  }
  catEl.innerHTML = Object.entries(cats).map(([k, v]) => {
    const pct = Math.round((v / total) * 100);
    return `
      <div style="margin-bottom:14px;">
        <div style="display:flex;justify-content:space-between;margin-bottom:5px;font-size:13px;">
          <span>${typeIcon(k)} ${k}</span>
          <span style="font-weight:600;font-family:'DM Mono',monospace">
            ${v} <span style="color:var(--gray-400);font-weight:400">(${pct}%)</span>
          </span>
        </div>
        <div style="height:6px;background:var(--gray-100);border-radius:3px;overflow:hidden;">
          <div style="height:100%;width:${pct}%;background:var(--blue);border-radius:3px;transition:width 0.5s"></div>
        </div>
      </div>
    `;
  }).join('');
}
