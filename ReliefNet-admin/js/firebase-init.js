import { initializeApp } from "https://www.gstatic.com/firebasejs/10.12.0/firebase-app.js";
import { getAuth, signInWithEmailAndPassword, signOut as fbSignOut, onAuthStateChanged }
  from "https://www.gstatic.com/firebasejs/10.12.0/firebase-auth.js";
import { getFirestore, doc, getDoc } from "https://www.gstatic.com/firebasejs/10.12.0/firebase-firestore.js";

import { loadAll } from "./overview.js";

const firebaseConfig = {
  apiKey: "AIzaSyBC2Hq0GXQlnYrAg0LN4Ux3Jw9MDiEjB5A",
  authDomain: "reliefnet-eb5f2.firebaseapp.com",
  projectId: "reliefnet-eb5f2",
  storageBucket: "reliefnet-eb5f2.firebasestorage.app",
  messagingSenderId: "838284269034",
  appId: "1:838284269034:web:faa27d1bb05c12f5f38e93",
  measurementId: "G-EMwFVC2PZR"
};

export const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);

// AUTH STATE LISTENER
onAuthStateChanged(auth, async user => {
  if (user) {
    // Check admin role before granting access
    try {
      const userDoc = await getDoc(doc(db, 'users', user.uid));
      const userData = userDoc.data();
      if (!userData?.isAdmin) {
        const errEl = document.getElementById('auth-error');
        errEl.textContent = 'Access denied. This account does not have admin privileges.';
        errEl.style.display = 'block';
        await fbSignOut(auth);
        return;
      }
    } catch (e) {
      console.warn('Could not verify admin role:', e);
      // Allow access if we can't check — Firestore rules should enforce this
    }
    document.getElementById('auth-screen').style.display = 'none';
    document.getElementById('app').style.display = 'flex';
    document.getElementById('admin-email').textContent = user.email;
    document.getElementById('admin-avatar').textContent = user.email[0].toUpperCase();
    document.getElementById('overview-date').textContent = new Date().toLocaleDateString('en-IN', {
      weekday: 'long', year: 'numeric', month: 'long', day: 'numeric'
    });
    loadAll();
  } else {
    document.getElementById('auth-screen').style.display = 'flex';
    document.getElementById('app').style.display = 'none';
    // Clean up active real-time listeners
    try {
      import('./reports.js').then(m => m.unsubReports());
      import('./applications.js').then(m => m.unsubApps());
      import('./volunteers.js').then(m => m.unsubVolunteers());
    } catch (err) {
      console.warn('Could not clean up listeners:', err);
    }
  }
});

// SIGN IN
window.signIn = async () => {
  const email = document.getElementById('email-input').value.trim();
  const pass  = document.getElementById('pass-input').value;
  const errEl = document.getElementById('auth-error');
  const btn   = document.querySelector('.auth-card .btn-primary');
  if (!email || !pass) {
    errEl.textContent = 'Please enter both email and password.';
    errEl.style.display = 'block';
    return;
  }
  errEl.style.display = 'none';
  btn.disabled = true;
  btn.innerHTML = '<span class="btn-spinner"></span>Signing in...';
  try {
    await signInWithEmailAndPassword(auth, email, pass);
  } catch (e) {
    const msg = e.code === 'auth/network-request-failed' ? 'Network error. Check your connection.'
              : e.code === 'auth/too-many-requests' ? 'Too many attempts. Try again later.'
              : 'Invalid email or password.';
    errEl.textContent = msg;
    errEl.style.display = 'block';
    btn.disabled = false;
    btn.textContent = 'Sign In';
  }
};

// SIGN OUT
window.signOut = async () => { await fbSignOut(auth); };

// ENTER KEY on password field
document.getElementById('pass-input').addEventListener('keydown', e => {
  if (e.key === 'Enter') window.signIn();
});
