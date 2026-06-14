import { db, auth } from "./firebase-init.js";
import { collection, addDoc, deleteDoc, doc, serverTimestamp, query, orderBy, onSnapshot, limit } from "https://www.gstatic.com/firebasejs/10.12.0/firebase-firestore.js";
import { formatTime, showToast, emptyRow, esc, logAdminAction } from "./utils.js";

let unsubscribeBroadcasts = null;
let allBroadcasts = [];

export async function loadBroadcasts() {
    if (unsubscribeBroadcasts) unsubscribeBroadcasts();
    const q = query(collection(db, "broadcasts"), orderBy("timestamp", "desc"), limit(20));

    unsubscribeBroadcasts = onSnapshot(q, (snap) => {
        allBroadcasts = snap.docs.map(d => ({ id: d.id, ...d.data() }));
        renderBroadcasts();
    }, (err) => {
        console.error("Broadcasts subscription error:", err);
    });
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
                <div style="font-weight:600; font-size:13px; color:var(--gray-900);">${esc(b.title)}</div>
                <div style="font-size:11px; color:var(--gray-500); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 200px;">${esc(b.message)}</div>
            </td>
            <td>
                <span class="badge ${b.level === 'Critical' ? 'badge-rejected' : b.level === 'Warning' ? 'badge-pending' : 'badge-active'}" style="font-size:10px;">${esc(b.level)}</span>
            </td>
            <td style="font-size:11px; color:var(--gray-400); white-space: nowrap;">${formatTime(b.timestamp)}</td>
            <td>
                <button class="action-btn btn-reject" onclick="deleteAlert('${b.id}')" style="padding: 4px 8px; font-size: 10px;">Delete</button>
            </td>
        </tr>
    `).join("");
}

window.deleteAlert = async (id) => {
    if (!confirm("Are you sure you want to delete this broadcast? It will be removed from all users' apps.")) return;

    try {
        await deleteDoc(doc(db, "broadcasts", id));
        showToast("Broadcast deleted");
        logAdminAction("delete_broadcast", id);
    } catch (e) {
        showToast("Error deleting: " + e.message);
    }
};

window.sendBroadcast = async () => {
    const title = document.getElementById("alert-title").value.trim();
    const level = document.getElementById("alert-level").value;
    const message = document.getElementById("alert-message").value.trim();
    const btn = document.querySelector("#page-broadcasts .btn-primary");

    if (!title || !message) {
        showToast("Please fill in both title and message");
        return;
    }

    if (!confirm(`Are you sure you want to send this ${level} alert to ALL users?`)) return;

    btn.disabled = true;
    btn.textContent = "Broadcasting...";

    try {
        const payload = {
            title,
            level,
            message,
            timestamp: serverTimestamp(),
            sentBy: auth.currentUser.email
        };

        // 1. Add to Firestore broadcasts collection
        await addDoc(collection(db, "broadcasts"), payload);

        // 2. Add to global alerts collection for app notifications
        await addDoc(collection(db, "alerts"), {
            ...payload,
            type: "broadcast",
            isRead: false
        });

        // Log the admin action
        logAdminAction("emergency_broadcast", "all_users", { title, level });

        showToast("Emergency broadcast sent successfully!");
        document.getElementById("alert-title").value = "";
        document.getElementById("alert-message").value = "";
    } catch (e) {
        showToast("Error: " + e.message);
    } finally {
        btn.disabled = false;
        btn.innerHTML = `<svg class="icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" style="width:18px;height:18px;"><path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"></path><path d="M13.73 21a2 2 0 0 1-3.46 0"></path></svg> Send Emergency Broadcast`;
    }
};
