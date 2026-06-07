import { initializeApp } from "https://www.gstatic.com/firebasejs/10.12.0/firebase-app.js";
import { getAuth, signInWithEmailAndPassword, signOut as fbSignOut, onAuthStateChanged }
  from "https://www.gstatic.com/firebasejs/10.12.0/firebase-auth.js";
import { getFirestore } from "https://www.gstatic.com/firebasejs/10.12.0/firebase-firestore.js";

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
onAuthStateChanged(auth, user => {
  if (user) {
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
  }
});

// SIGN IN
window.signIn = async () => {
  const email = document.getElementById('email-input').value;
  const pass  = document.getElementById('pass-input').value;
  const errEl = document.getElementById('auth-error');
  errEl.style.display = 'none';
  try {
    await signInWithEmailAndPassword(auth, email, pass);
  } catch (e) {
    errEl.textContent = 'Invalid email or password.';
    errEl.style.display = 'block';
  }
};

// SIGN OUT
window.signOut = async () => { await fbSignOut(auth); };

// ENTER KEY on password field
document.getElementById('pass-input').addEventListener('keydown', e => {
  if (e.key === 'Enter') window.signIn();
});
