import { loadReports, allReports } from "./reports.js";
import { loadApplications, allApps } from "./applications.js";
import { loadVolunteers, allVolunteers } from "./volunteers.js";
import { typeIcon, urgencyBadge, statusBadge, formatTime, emptyRow, esc } from "./utils.js";
import { db } from "./firebase-init.js";
import { collection, query, orderBy, limit, onSnapshot } from "https://www.gstatic.com/firebasejs/10.12.0/firebase-firestore.js";

export async function loadAll() {
  await Promise.all([loadReports(), loadApplications(), loadVolunteers()]);
  initActivityStream();
  renderOverview();
}

let overviewMap = null;
let markersGroup = null;
let currentTileLayer = null;
let chartCategories = null;
let chartPriority = null;
let unsubscribeActivity = null;

function initActivityStream() {
  if (unsubscribeActivity) unsubscribeActivity();
  const q = query(collection(db, 'admin_actions'), orderBy('timestamp', 'desc'), limit(10));
  unsubscribeActivity = onSnapshot(q, snap => {
    const actions = snap.docs.map(d => ({ id: d.id, ...d.data() }));
    renderActivityFeed(actions);
  });
}

function renderActivityFeed(actions) {
  const container = document.getElementById('intel-activity');
  if (!container) return;
  if (actions.length === 0) {
    container.innerHTML = '<div style="font-size:11px; color:var(--text-secondary); text-align:center; padding:10px;">NO RECENT ACTIONS</div>';
    return;
  }
  container.innerHTML = actions.map(a => `
    <div class="activity-item">
      <span class="time">${formatTime(a.timestamp).split(',')[1]}</span>
      <strong>${esc(a.adminEmail.split('@')[0])}</strong> ${esc(a.action.replace('_', ' '))}
      <div style="font-size:10px; color:var(--text-secondary);">ID: ${a.targetId.substring(0,8)}</div>
    </div>
  `).join('');
}

export function renderOverview() {
  const isDark = document.documentElement.classList.contains('dark-mode');

  // Recent 10 reports for the incident stream
  const recent = allReports.slice(0, 10);
  const tbody = document.getElementById('overview-reports-body');
  if (recent.length === 0) {
    tbody.innerHTML = emptyRow(1, 'empty', 'No reports yet');
  } else {
    tbody.innerHTML = recent.map(r => `
      <tr onclick="window.openReport('${r.id}')">
        <td style="padding: 16px 20px;">
          <div style="display:flex; justify-content:space-between; align-items:start;">
            <div style="display:flex; gap:12px; align-items:center;">
              ${typeIcon(r.issueType)}
              <div>
                <div style="font-weight:700; font-size:13px; color:var(--text-primary);">${esc(r.issueType)}</div>
                <div class="mono" style="font-size:10px; color:var(--text-secondary); opacity:0.8;">ID: ${r.id.substring(0,8)}</div>
              </div>
            </div>
            <div style="text-align:right;">
               <div style="font-size:10px; font-weight:700; color:var(--text-secondary);">${formatTime(r.timestamp).split(',')[1]}</div>
               ${urgencyBadge(r.urgency)}
            </div>
          </div>
          <div style="margin-top:8px; font-size:12px; color:var(--text-secondary); overflow:hidden; text-overflow:ellipsis; white-space:nowrap; max-width:300px;">
            ${esc(r.description)}
          </div>
        </td>
      </tr>
    `).join('');
  }

  // ─── MAP ─────────────────────
  try {
    if (typeof L !== 'undefined') {
      const mapContainer = document.getElementById('overview-map');
      if (mapContainer) {
        if (!overviewMap) {
          overviewMap = L.map('overview-map', { zoomControl: false }).setView([20.5937, 78.9629], 5);
          markersGroup = L.featureGroup().addTo(overviewMap);
          L.control.zoom({ position: 'bottomright' }).addTo(overviewMap);
        }

        const tileUrl = isDark
          ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
          : 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';

        if (currentTileLayer) {
          overviewMap.removeLayer(currentTileLayer);
        }
        currentTileLayer = L.tileLayer(tileUrl, {
          attribution: '&copy; OpenStreetMap'
        }).addTo(overviewMap);

        markersGroup.clearLayers();
        
        allReports.filter(r => r.lat && r.lng && r.status !== 'completed').forEach(r => {
          const color = r.urgency === 'High' ? '#DC2626' : r.urgency === 'Medium' ? '#EA580C' : '#2563EB';
          const marker = L.circleMarker([r.lat, r.lng], {
            radius: 8, fillColor: color, color: '#fff', weight: 2, fillOpacity: 0.9
          });
          marker.bindPopup(`<div class="mono" style="font-size:11px; color: #0F172A;">ID: ${r.id.substring(0,8)}<br><b>${r.issueType}</b></div>`);
          marker.addTo(markersGroup);
        });

        if (markersGroup.getLayers().length > 0) overviewMap.fitBounds(markersGroup.getBounds(), { padding: [50, 50] });

        setTimeout(() => {
          overviewMap.invalidateSize();
        }, 100);
      }
    }
  } catch (err) { console.error(err); }

  // ─── INTELLIGENCE WIDGETS ─────────────────────
  renderIntelligenceWidgets();

  // ─── CHARTS ─────────────────────
  try {
    if (typeof Chart !== 'undefined') {
      const ctxCat = document.getElementById('chart-categories');
      if (ctxCat) {
        if (chartCategories) chartCategories.destroy();
        const counts = {};
        allReports.forEach(r => counts[r.issueType] = (counts[r.issueType] || 0) + 1);
        const style = getComputedStyle(document.body);
        const textColor = style.getPropertyValue('--text-secondary').trim();

        chartCategories = new Chart(ctxCat, {
          type: 'doughnut',
          data: {
            labels: Object.keys(counts),
            datasets: [{
              data: Object.values(counts),
              backgroundColor: ['#DC2626', '#EA580C', '#2563EB', '#16A34A', '#94A3B8', '#8B5CF6', '#EC4899'],
              borderWidth: 0
            }]
          },
          options: {
            responsive: true, maintainAspectRatio: false,
            plugins: {
              legend: {
                position: 'bottom',
                labels: { boxWidth: 8, color: textColor, font: { size: 10, weight: '600', family: 'Inter' } }
              }
            }
          }
        });
      }

      const ctxPrio = document.getElementById('chart-priority');
      if (ctxPrio) {
        if (chartPriority) chartPriority.destroy();
        const pCounts = { 'High': 0, 'Medium': 0, 'Low': 0 };
        allReports.forEach(r => { if(pCounts[r.urgency] !== undefined) pCounts[r.urgency]++; });

        chartPriority = new Chart(ctxPrio, {
          type: 'pie',
          data: {
            labels: ['High', 'Medium', 'Low'],
            datasets: [{
              data: [pCounts.High, pCounts.Medium, pCounts.Low],
              backgroundColor: ['#DC2626', '#EA580C', '#16A34A'],
              borderWidth: 0
            }]
          },
          options: {
            responsive: true, maintainAspectRatio: false,
            plugins: {
              legend: {
                position: 'right',
                labels: { boxWidth: 8, font: { size: 10, weight: '600' } }
              }
            }
          }
        });
      }
    }
  } catch (e) {}
}

function renderIntelligenceWidgets() {
  // 1. Priority handled by Chart

  // 2. Response Performance
  const completed = allReports.filter(r => r.status === 'completed' && r.timestamp && r.resolvedAt);
  let totalResolveMs = 0;
  completed.forEach(r => {
    const start = r.timestamp.toDate ? r.timestamp.toDate() : new Date(r.timestamp);
    const end = r.resolvedAt.toDate ? r.resolvedAt.toDate() : new Date(r.resolvedAt);
    totalResolveMs += (end - start);
  });

  const avgRes = completed.length > 0 ? (totalResolveMs / completed.length / 3600000).toFixed(1) + 'h' : '—';
  document.getElementById('intel-avg-res').textContent = avgRes;
  document.getElementById('intel-avg-resp').textContent = '~15m'; // Static mock for now

  const resRate = allReports.length > 0 ? Math.round((allReports.filter(r => r.status === 'completed').length / allReports.length) * 100) : 0;
  document.getElementById('intel-res-rate-pct').textContent = resRate + '%';
  document.getElementById('intel-res-rate-bar').style.width = resRate + '%';

  // 3. Volunteer Status
  const assignedVols = new Set();
  allReports.filter(r => r.status !== 'completed').forEach(r => {
    (r.assignedVolunteers || []).forEach(uid => assignedVols.add(uid));
  });

  document.getElementById('intel-vol-assigned').textContent = assignedVols.size;
  document.getElementById('intel-vol-active').textContent = allVolunteers.length;
  document.getElementById('intel-vol-avail').textContent = Math.max(0, allVolunteers.length - assignedVols.size);
  document.getElementById('intel-vol-offline').textContent = '0';

  // 4. Pending Applications
  const pendingApps = allApps.filter(a => a.status === 'pending').length;
  const pendingAppsEl = document.getElementById('intel-pending-apps');
  if (pendingAppsEl) pendingAppsEl.textContent = pendingApps;

  // 5. System Health Status Mock (Visual only for now)
  const syncEl = document.getElementById('health-sync');
  if (syncEl) syncEl.textContent = 'LIVE ' + new Date().toLocaleTimeString('en-IN', { hour:'2-digit', minute:'2-digit' });

  // 6. Hotspots
  const clusters = {};
  allReports.forEach(r => {
    if (r.lat && r.lng) {
      const key = `${r.lat.toFixed(1)},${r.lng.toFixed(1)}`;
      clusters[key] = (clusters[key] || 0) + 1;
    }
  });
  const topHotspots = Object.entries(clusters).sort((a, b) => b[1] - a[1]).slice(0, 3);
  const hotspotContainer = document.getElementById('intel-hotspots');
  if (hotspotContainer) {
    hotspotContainer.innerHTML = topHotspots.map(([loc, count]) => `
      <div class="hotspot-item">
        <span style="color:var(--text-secondary); font-family:monospace;">LOC ${loc}</span>
        <span class="val">${count} Reports</span>
      </div>
    `).join('') || '<div style="font-size:11px; color:var(--text-secondary);">NO HOTSPOTS</div>';
  }
}

export function invalidateOverviewMap() {
  if (overviewMap) {
    setTimeout(() => {
      overviewMap.invalidateSize();
      if (markersGroup && markersGroup.getLayers().length > 0) {
        try {
          overviewMap.fitBounds(markersGroup.getBounds());
        } catch(e) {}
      }
    }, 200);
  }
}
