import { loadReports, allReports } from "./reports.js";
import { loadApplications, allApps } from "./applications.js";
import { loadVolunteers } from "./volunteers.js";
import { typeIcon, urgencyBadge, statusBadge, formatTime, emptyRow, esc } from "./utils.js";

export async function loadAll() {
  await Promise.all([loadReports(), loadApplications(), loadVolunteers()]);
  renderOverview();
}

let overviewMap = null;
let markersGroup = null;
let currentTileLayer = null;
let chartCategories = null;

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

        // Update tile layer based on theme
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
              backgroundColor: ['#DC2626', '#EA580C', '#2563EB', '#16A34A', '#94A3B8'],
              borderWidth: 0
            }]
          },
          options: {
            responsive: true, maintainAspectRatio: false,
            plugins: {
              legend: {
                position: 'bottom',
                labels: {
                  boxWidth: 8,
                  color: textColor,
                  font: { size: 10, weight: '600', family: 'Inter' }
                }
              }
            }
          }
        });
      }
    }
  } catch (e) {}
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
