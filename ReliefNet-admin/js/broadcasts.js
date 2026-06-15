import { db, auth } from "./firebase-init.js";
import { collection, addDoc, serverTimestamp, query, orderBy, onSnapshot, limit, deleteDoc, doc } from "https://www.gstatic.com/firebasejs/10.12.0/firebase-firestore.js";
import { formatTime, showToast, emptyRow, esc, logAdminAction } from "./utils.js";

let unsubscribeBroadcasts = null;
let allBroadcasts = [];

export async function loadBroadcasts() {
    if (unsubscribeBroadcasts) unsubscribeBroadcasts();
    const q = query(collection(db, "broadcasts"), orderBy("timestamp", "desc"), limit(20));
    unsubscribeBroadcasts = onSnapshot(q, (snap) => {
        allBroadcasts = snap.docs.map(d => ({ id: d.id, ...d.data() }));
        renderBroadcasts();
    }, (err) => { console.error(err); });
}

function renderBroadcasts() {
    const tbody = document.getElementById("broadcasts-body");
    if (!tbody) return;
    if (allBroadcasts.length === 0) {
        tbody.innerHTML = emptyRow(4, "empty", "No broadcasts sent yet");
        return;
    }
    tbody.innerHTML = allBroadcasts.map(b => `
        <tr>
            <td>
                <div style="font-weight:700; font-size:13px; color: var(--text-primary);">${esc(b.title)}</div>
                <div style="font-size:11px; color:var(--text-secondary); overflow:hidden; text-overflow:ellipsis; white-space:nowrap; max-width:260px;">${esc(b.message)}</div>
            </td>
            <td>
                <span class="badge-pill ${b.level === 'Critical' ? 'badge-critical' : b.level === 'Warning' ? 'badge-warning' : 'badge-info'}">${esc(b.level)}</span>
            </td>
            <td style="font-size:11px; color:var(--text-secondary);">${formatTime(b.timestamp)}</td>
            <td><button class="btn-back" style="color:var(--critical); border-color:var(--border); padding: 4px 12px; font-size: 11px;" onclick="deleteAlert('${b.id}')">Delete</button></td>
        </tr>
    `).join("");
}

window.deleteAlert = async (id) => {
    if (!confirm("Are you sure you want to delete this broadcast? It will be removed from all users' apps.")) return;
    try {
        await deleteDoc(doc(db, "broadcasts", id));
        showToast("Broadcast deleted");
        logAdminAction("delete_broadcast", id);
    } catch (e) { showToast(e.message); }
};

window.sendBroadcast = async () => {
    const title = document.getElementById("alert-title").value.trim();
    const level = document.getElementById("alert-level").value;
    const message = document.getElementById("alert-message").value.trim();
    const btn = document.querySelector("#page-broadcasts .btn-primary");
    if (!title || !message) return showToast("Please fill in both title and message");
    if (!confirm(`Are you sure you want to send this ${level} alert to ALL users?`)) return;
    btn.disabled = true; btn.textContent = "Broadcasting...";
    try {
        const payload = { title, level, message, timestamp: serverTimestamp(), sentBy: auth.currentUser.email };
        await addDoc(collection(db, "broadcasts"), payload);
        await addDoc(collection(db, "alerts"), { ...payload, type: "broadcast", isRead: false });
        logAdminAction("emergency_broadcast", "all_users", { title, level });
        showToast("Emergency broadcast sent successfully!");
        document.getElementById("alert-title").value = "";
        document.getElementById("alert-message").value = "";
    } catch (e) { showToast(e.message); }
    finally { btn.disabled = false; btn.textContent = "Send Emergency Broadcast"; }
};
