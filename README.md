<div align="center">

<br />

<pre>
██████╗ ███████╗██╗     ██╗███████╗███████╗███╗   ██╗███████╗████████╗
██╔══██╗██╔════╝██║     ██║██╔════╝██╔════╝████╗  ██║██╔════╝╚══██╔══╝
██████╔╝█████╗  ██║     ██║█████╗  █████╗  ██╔██╗ ██║█████╗     ██║   
██╔══██╗██╔══╝  ██║     ██║██╔══╝  ██╔══╝  ██║╚██╗██║██╔══╝     ██║   
██║  ██║███████╗███████╗██║███████╗██║     ██║ ╚████║███████╗   ██║   
╚═╝  ╚═╝╚══════╝╚══════╝╚═╝╚══════╝╚═╝     ╚═╝  ╚═══╝╚══════╝   ╚═╝   
</pre>

**NGO field reporting & volunteer dispatch — powered by Gemini AI**

[![Google Solution Challenge](https://img.shields.io/badge/Google_Solution_Challenge-2026-4285F4?style=for-the-badge&logo=google&logoColor=white)](https://developers.google.com/community/gdsc-solution-challenge)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Firestore-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com)
[![Gemini AI](https://img.shields.io/badge/Gemini-AI-8E75B2?style=for-the-badge&logo=google&logoColor=white)](https://ai.google.dev)
[![Version](https://img.shields.io/badge/version-1.0.0-22C55E?style=for-the-badge)](https://github.com/your-username/reliefnet/releases)

<br />

</div>

---

## What is ReliefNet?

ReliefNet bridges the gap between **disaster-affected communities** and **verified NGO field volunteers**. When a crisis hits — food shortage, medical emergency, shelter need — anyone can file a geo-tagged report in seconds. Verified volunteers nearby see it on a live dashboard, accept the task, navigate to the site, and submit photo proof on completion.

Every report is instantly analyzed by **Gemini AI** to surface urgency insights, required skills, and actionable solutions — before a single volunteer is dispatched.

---

## 📥 Download App

Get the latest version of **ReliefNet APK**:

👉 [Download Latest APK](https://github.com/ReliefNet/ReliefNet/releases/download/v1.0.0/reliefnet-v1.0.0.apk)

> ⚠️ Enable "Install from unknown sources" on your Android device before installing.

---

## 🎥 Demo Video

Watch ReliefNet in action:

[![Demo Video](https://img.youtube.com/vi/aYeGnr154mM/maxresdefault.jpg)](https://youtu.be/aYeGnr154mM)

---

## 📊 Pitch Deck

View our Google Solution Challenge 2026 presentation:

👉 [Open Presentation on Canva](https://canva.link/nstf4xhm61ehjbu)

---

## Screenshots

| Home | Dashboard | Report Issue | AI Analysis |
|:---:|:---:|:---:|:---:|
| ![](screenshots/home.jpeg) | ![](screenshots/dashboard.jpeg) | ![](screenshots/report.jpeg) | ![](screenshots/ai_analysis.jpeg) |

| Volunteer Task | Task Workflow | Profile | Settings |
|:---:|:---:|:---:|:---:|
| ![](screenshots/volunteer_task.jpeg) | ![](screenshots/volunteer_workflow.jpeg) | ![](screenshots/profile.jpeg) | ![](screenshots/settings.jpeg) |

---

## Features

<table>
<tr>
<td width="50%">

### 🗺️ Live Crisis Dashboard
Real-time Firestore feed of all active reports. Filter by urgency level, sort by **nearest**, **latest**, or **most urgent**. Distance calculated via Haversine formula from the volunteer's live GPS. Completed tasks automatically sink to the bottom.

</td>
<td width="50%">

### ✦ Gemini AI Analysis
Every submitted report is analyzed by Gemini and saved back to Firestore:
- Situation summary
- 3 actionable solutions
- Required skills (e.g. First Aid, Logistics)
- Estimated people affected
- Action priority level

</td>
</tr>
<tr>
<td width="50%">

### 📋 Field Report Submission
File geo-tagged reports with:
- Issue type (Food / Medical / Shelter / Other)
- Urgency level (Low / Medium / High)
- Auto-fetched GPS coordinates
- Photo & video attachments (up to 5)
- Optional AI analysis preview before submitting

</td>
<td width="50%">

### 🙋 Volunteer Task Flow
Structured 4-stage workflow:

```
Assigned → En Route → On Site → Done
```

Arrival confirmed via **1km geofence**. Completion requires photo proof + note, stored in Firebase Storage.

</td>
</tr>
<tr>
<td width="50%">

### 👤 Verified Volunteers
Role-based access — only verified NGO volunteers can accept tasks. Profiles track reports submitted, tasks accepted, tasks completed, and success rate. Each volunteer gets a unique Volunteer ID.

</td>
<td width="50%">

### ⚙️ Settings
- Dark / Light mode
- Emergency hotlines (Police 100, Ambulance 102, Fire 101)
- Notification preferences
- Language & region
- Privacy, cache, account controls

</td>
</tr>
</table>

---

## Tech Stack

| Layer | Technology |
|---|---|
| **Mobile Framework** | Flutter (Dart) |
| **Database** | Firebase Firestore (real-time) |
| **Authentication** | Firebase Auth + Google Sign-In |
| **File Storage** | Firebase Storage |
| **AI / ML** | Gemini API (`gemini-1.5-flash`) |
| **Maps & Navigation** | Google Maps API |
| **Places Search** | Google Places API (New) |
| **Location** | Geolocator (Haversine distance) |
| **State Management** | Provider + SharedPreferences |

---

## Architecture

```
lib/
├── main.dart                     # App entry, routes, theme
├── main-pages/
│   ├── dashboard_page.dart       # Live report feed + AI overview
│   ├── report_page.dart          # Report submission form
│   ├── volunteer_page.dart       # My Tasks (volunteer flow)
│   ├── profile_page.dart         # User stats & profile
│   └── settings_page.dart        # App settings
├── services/
│   └── gemini_service.dart       # Gemini API (direct HTTP)
└── widgets/
    ├── ai_summary_card.dart      # Reusable AI analysis card
    └── app_bar_component.dart    # Shared app bar + drawer
```

---

## Getting Started

### Prerequisites

- Flutter SDK `>=3.0.0`
- Firebase project (Firestore, Auth, Storage enabled)
- [Gemini API key](https://aistudio.google.com/apikey)
- Google Maps API key

### Setup

```bash
# 1. Clone
git clone https://github.com/your-username/reliefnet.git
cd reliefnet

# 2. Install dependencies
flutter pub get

# 3. Add Firebase config
# → android/app/google-services.json
# → ios/Runner/GoogleService-Info.plist

# 4. Run
flutter run --dart-define=GOOGLE_API_KEY=your_gemini_key_here

# 5. Build release APK
flutter build apk --release --dart-define=GOOGLE_API_KEY=your_gemini_key_here
```

### VS Code Launch Config

Create `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "ReliefNet",
      "request": "launch",
      "type": "dart",
      "args": ["--dart-define=GOOGLE_API_KEY=your_key_here"]
    }
  ]
}
```

> ⚠️ Add `.vscode/launch.json` and `.env` to `.gitignore` — never commit API keys.

### Firestore Index Required

The volunteer tasks query requires a composite index on `reports`:

- `assignedVolunteers` (array-contains) + `timestamp` (descending)

Firebase will prompt you with a direct link to create it on first run.

---

## Volunteer Flow

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│ Report Filed │───▶│  Gemini AI   │───▶│  Volunteer   │───▶│  En Route   │───▶│     Done     │
│ by citizen   │    │   Analysis   │    │   Accepts    │    │ Google Maps  │    │ Photo Proof  │
└──────────────┘    └──────────────┘    └──────────────┘    └──────────────┘    └──────────────┘
```

---

## UN SDGs Addressed

| SDG | Goal | How ReliefNet helps |
|:---:|---|---|
| **1** | No Poverty | Connecting underserved communities to aid and NGO resources |
| **3** | Good Health & Well-Being | Rapid medical emergency response and dispatch |
| **11** | Sustainable Cities | Organized, data-driven disaster response infrastructure |
| **17** | Partnerships for the Goals | NGO · volunteer · community coordination platform |

---

## Team

<table>
<tr>
<td align="center" width="33%">
<b>Ramandeep Singh</b> 👑<br/>
<sub>Team Lead · Flutter Development · UI/UX · Gemini AI · Integration</sub>
</td>
<td align="center" width="33%">
<b>Japneet Singh</b><br/>
<sub>Flutter Development · Firebase Backend · Auth · Gemini AI · Integration</sub>
</td>
<td align="center" width="33%">
<b>Amandeep Singh</b><br/>
<sub>Presentation · Video Editing · Logo / App Icon Design</sub>
</td>
</tr>
</table>

**Institution:** GTBIT, New Delhi  
**Submission:** Google Solution Challenge 2026

---

## License

Submitted as part of the Google Solution Challenge 2026. Built for educational and humanitarian purposes.

---

<div align="center">
<br/>
<b>ReliefNet v1.0.0</b> · Made with ❤️ for communities
<br/><br/>

[![GTBIT](https://img.shields.io/badge/GTBIT-New_Delhi-blue?style=flat-square)](https://gtbit.edu.in)
[![Solution Challenge](https://img.shields.io/badge/Google-Solution_Challenge_2026-4285F4?style=flat-square&logo=google)](https://developers.google.com/community/gdsc-solution-challenge)

</div>