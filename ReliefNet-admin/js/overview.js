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
let chartCategories = null;
let chartUrgency = null;
let chartTrends = null;

export function renderOverview() {
  const total       = allReports.length;
  const active      = allReports.filter(r => r.status !== 'completed' && r.status !== 'suspected_spam' && r.status !== 'flagged').length;
  const resolved    = allReports.filter(r => r.status === 'completed').length;
  const spam        = allReports.filter(r => r.status === 'suspected_spam' || r.status === 'flagged').length;
  const pendingApps = allApps.filter(a => a.status === 'pending').length;

  document.getElementById('stat-total').textContent       = total;
  document.getElementById('stat-active').textContent      = active;
  document.getElementById('stat-resolved').textContent    = resolved;
  document.getElementById('stat-spam').textContent        = spam;
  document.getElementById('stat-pending-apps').textContent = pendingApps;

  // Recent 5 reports
  const recent = allReports.slice(0, 5);
  const tbody = document.getElementById('overview-reports-body');
  if (recent.length === 0) {
    tbody.innerHTML = emptyRow(4, 'empty', 'No reports yet');
  } else {
    tbody.innerHTML = recent.map(r => `
      <tr style="cursor:pointer" onclick="window.openReport('${r.id}')">
        <td>${typeIcon(r.issueType)} ${esc(r.issueType || '—')}</td>
        <td>${urgencyBadge(r.urgency)}</td>
        <td>${statusBadge(r.status)}</td>
        <td style="font-size:12px;color:var(--gray-400)">${formatTime(r.timestamp)}</td>
      </tr>
    `).join('');
  }

  // ─── LEAFLET MAP INITIALIZATION & SYNC ─────────────────────
  try {
    if (typeof L !== 'undefined') {
      const mapContainer = document.getElementById('overview-map');
      if (mapContainer) {
        if (!overviewMap) {
          overviewMap = L.map('overview-map').setView([20.5937, 78.9629], 5);
          L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            maxZoom: 19,
            attribution: '© OpenStreetMap'
          }).addTo(overviewMap);
          markersGroup = L.featureGroup().addTo(overviewMap);
          
          // Force Leaflet to recalculate container size on first render
          setTimeout(() => {
            if (overviewMap) overviewMap.invalidateSize();
          }, 200);
        } else {
          markersGroup.clearLayers();
          // Force layout refresh on updates
          overviewMap.invalidateSize();
        }

        const reportsWithCoords = allReports.filter(r => {
          const lat = Number(r.lat);
          const lng = Number(r.lng);
          return !isNaN(lat) && !isNaN(lng) && r.lat !== undefined && r.lng !== undefined && r.status !== 'completed';
        });
        
        reportsWithCoords.forEach(r => {
          const lat = Number(r.lat);
          const lng = Number(r.lng);
          const markerColor = r.urgency === 'High' ? '#EF4444' : r.urgency === 'Medium' ? '#F97316' : '#22C55E';
          const marker = L.circleMarker([lat, lng], {
            radius: 8,
            fillColor: markerColor,
            color: '#ffffff',
            weight: 2,
            opacity: 1,
            fillOpacity: 0.8
          });

          marker.bindPopup(`
            <div style="font-family:'DM Sans',sans-serif;font-size:13px;color:var(--gray-800);line-height:1.4;">
              <strong style="font-size:14px;color:var(--gray-900);display:block;margin-bottom:2px;">${typeIcon(r.issueType)} ${esc(r.issueType)}</strong>
              <span style="font-size:11px;color:var(--gray-400);font-family:'DM Mono',monospace;display:block;margin-bottom:4px;">ID: ${r.id}</span>
              <p style="margin:4px 0 8px;max-width:180px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;color:var(--gray-600);">${esc(r.description)}</p>
              <div style="display:flex;justify-content:space-between;align-items:center;margin-top:6px;">
                <span style="font-size:11px;font-weight:700;color:${markerColor};">${r.urgency}</span>
                <button onclick="window.openReport('${r.id}')" style="background:var(--blue);color:white;border:none;border-radius:6px;padding:4px 10px;cursor:pointer;font-size:11px;font-weight:600;font-family:inherit;transition:opacity 0.2s;">View →</button>
              </div>
            </div>
          `);
          marker.addTo(markersGroup);
        });

        if (reportsWithCoords.length > 0) {
          try {
            overviewMap.fitBounds(markersGroup.getBounds(), { padding: [40, 40] });
          } catch (_) {}
        }
      }
    } else {
      console.warn("Leaflet library L is not loaded.");
      const mapContainer = document.getElementById('overview-map');
      if (mapContainer) {
        mapContainer.innerHTML = '<div class="empty"><div class="empty-icon"><svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" style="width:48px;height:48px;color:var(--gray-400);"><polygon points="3 6 9 3 15 6 21 3 21 18 15 21 9 18 3 21"></polygon><line x1="9" y1="3" x2="9" y2="18"></line><line x1="15" y1="6" x2="15" y2="21"></line></svg></div><div class="empty-text">Map is offline (Leaflet failed to load)</div></div>';
      }
    }
  } catch (err) {
    console.error("Failed to initialize Overview Map:", err);
  }

  // ─── CHART.JS ANALYTICS DASHBOARD ──────────────────────────
  try {
    if (typeof Chart !== 'undefined') {
      const isDarkMode = document.documentElement.classList.contains('dark-mode');
      const textColor = isDarkMode ? '#D1D5DB' : '#6B7280';
      const gridColor = isDarkMode ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.06)';
      const borderCol = isDarkMode ? '#111827' : '#ffffff';

      // 1. Doughnut Chart: Categories
      const categoriesCount = {};
      allReports.forEach(r => {
        const cat = r.issueType || 'Other';
        categoriesCount[cat] = (categoriesCount[cat] || 0) + 1;
      });
      const catLabels = Object.keys(categoriesCount);
      const catData = Object.values(categoriesCount);
      const ctxCat = document.getElementById('chart-categories');

      if (ctxCat) {
        if (chartCategories) chartCategories.destroy();
        chartCategories = new Chart(ctxCat, {
          type: 'doughnut',
          data: {
            labels: catLabels,
            datasets: [{
              data: catData,
              backgroundColor: ['#2563EB', '#22C55E', '#EF4444', '#F97316', '#A855F7', '#6B7280'],
              borderWidth: 1.5,
              borderColor: borderCol
            }]
          },
          options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
              legend: {
                position: 'right',
                labels: {
                  boxWidth: 12,
                  font: { family: 'DM Sans', size: 11 },
                  color: textColor
                }
              }
            }
          }
        });
      }

      // 2. Bar Chart: Urgency
      const urgencyCount = { High: 0, Medium: 0, Low: 0 };
      allReports.forEach(r => {
        if (r.urgency in urgencyCount) {
          urgencyCount[r.urgency]++;
        }
      });
      const ctxUrg = document.getElementById('chart-urgency');

      if (ctxUrg) {
        if (chartUrgency) chartUrgency.destroy();
        chartUrgency = new Chart(ctxUrg, {
          type: 'bar',
          data: {
            labels: ['High', 'Medium', 'Low'],
            datasets: [{
              label: 'Reports',
              data: [urgencyCount.High, urgencyCount.Medium, urgencyCount.Low],
              backgroundColor: ['rgba(239, 68, 68, 0.85)', 'rgba(249, 115, 22, 0.85)', 'rgba(34, 197, 94, 0.85)'],
              borderRadius: 6
            }]
          },
          options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
              legend: { display: false }
            },
            scales: {
              x: {
                grid: { display: false },
                ticks: { color: textColor }
              },
              y: {
                beginAtZero: true,
                grid: { color: gridColor },
                ticks: { stepSize: 1, color: textColor }
              }
            }
          }
        });
      }

      // 3. Line Chart: Timeline (Last 7 Days)
      const days = [];
      const submissionsByDay = {};
      for (let i = 6; i >= 0; i--) {
        const date = new Date();
        date.setDate(date.getDate() - i);
        const dateString = date.toLocaleDateString('en-IN', { day: 'numeric', month: 'short' });
        days.push(dateString);
        submissionsByDay[dateString] = 0;
      }
      allReports.forEach(r => {
        const ts = r.timestamp;
        if (ts) {
          const d = ts.toDate ? ts.toDate() : new Date(ts);
          const str = d.toLocaleDateString('en-IN', { day: 'numeric', month: 'short' });
          if (str in submissionsByDay) {
            submissionsByDay[str]++;
          }
        }
      });
      const trendsData = days.map(d => submissionsByDay[d]);
      const ctxTrd = document.getElementById('chart-trends');

      if (ctxTrd) {
        if (chartTrends) chartTrends.destroy();
        chartTrends = new Chart(ctxTrd, {
          type: 'line',
          data: {
            labels: days,
            datasets: [{
              label: 'Submissions',
              data: trendsData,
              borderColor: '#2563EB',
              backgroundColor: 'rgba(37, 99, 235, 0.1)',
              fill: true,
              tension: 0.3,
              borderWidth: 2,
              pointBackgroundColor: '#2563EB'
            }]
          },
          options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
              legend: { display: false }
            },
            scales: {
              x: {
                grid: { display: false },
                ticks: { color: textColor }
              },
              y: {
                beginAtZero: true,
                grid: { color: gridColor },
                ticks: { stepSize: 1, color: textColor }
              }
            }
          }
        });
      }
    } else {
      console.warn("Chart.js is not loaded.");
      const breakdownEl = document.getElementById('category-breakdown');
      if (breakdownEl) {
        breakdownEl.innerHTML = '<div class="empty"><div class="empty-icon"><svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" style="width:48px;height:48px;color:var(--gray-400);"><line x1="18" y1="20" x2="18" y2="10"></line><line x1="12" y1="20" x2="12" y2="4"></line><line x1="6" y1="20" x2="6" y2="14"></line></svg></div><div class="empty-text">Charts are offline (Chart.js failed to load)</div></div>';
      }
    }
  } catch (err) {
    console.error("Failed to render Chart.js analytics:", err);
  }
}

// ─── LEAFLET FIX FOR DISPLAY TILE BUGS ───────────────────────
export function invalidateOverviewMap() {
  if (overviewMap) {
    overviewMap.invalidateSize();
    setTimeout(() => {
      if (overviewMap) {
        overviewMap.invalidateSize();
        if (markersGroup && markersGroup.getLayers().length > 0) {
          try {
            overviewMap.fitBounds(markersGroup.getBounds(), { padding: [40, 40] });
          } catch (_) {}
        }
      }
    }, 150);
  }
}

