(async () => {
  console.log("🚀 Initializing ReliefNet Full Demo Data Script (Ultimate Edition)...");

  const { initializeApp } = await import("https://www.gstatic.com/firebasejs/10.8.0/firebase-app.js");
  const { 
    getFirestore, collection, getDocs, writeBatch, doc, Timestamp
  } = await import("https://www.gstatic.com/firebasejs/10.8.0/firebase-firestore.js");

  const firebaseConfig = {
    apiKey: "AIzaSyBC2Hq0GXQlnYrAg0LN4Ux3Jw9MDiEjB5A",
    authDomain: "reliefnet-eb5f2.firebaseapp.com",
    projectId: "reliefnet-eb5f2",
    storageBucket: "reliefnet-eb5f2.firebasestorage.app",
    messagingSenderId: "838284269034",
    appId: "1:838284269034:web:faa27d1bb05c12f5f38e93"
  };

  const app = initializeApp(firebaseConfig);
  const db = getFirestore(app);

  const ADMIN_UID = "fDsMDtyhUhcd00Dpkr9Tv5XFtPF2"; // gmail@gmail.com

  const generateId = () => {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    let autoId = '';
    for (let i = 0; i < 20; i++) {
      autoId += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return autoId;
  };

  const randomDate = (daysAgo = 7, maxDays = 0) => {
    const d = new Date();
    d.setDate(d.getDate() - (maxDays + Math.random() * (daysAgo - maxDays)));
    return Timestamp.fromDate(d);
  };
  const generateVolId = () => Math.floor(100000000000 + Math.random() * 900000000000).toString();

  // Coordinates
  const OkhlaCluster = { lat: 28.5398, lng: 77.2758 };
  const GurgaonCluster = { lat: 28.4595, lng: 77.0266 };
  const generalLocations = [
    { name: "Noida Sector 62", lat: 28.6139, lng: 77.3598 },
    { name: "Ghaziabad Indirapuram", lat: 28.6415, lng: 77.3714 },
    { name: "Faridabad NIT", lat: 28.3892, lng: 77.3060 },
    { name: "Central Delhi", lat: 28.6139, lng: 77.2090 },
    { name: "Dwarka", lat: 28.5823, lng: 77.0500 },
    { name: "Vasant Kunj", lat: 28.5300, lng: 77.1600 },
    { name: "Laxmi Nagar", lat: 28.6300, lng: 77.2700 }
  ];

  const getClusterLoc = (base) => ({
    lat: base.lat + (Math.random() - 0.5) * 0.005,
    lng: base.lng + (Math.random() - 0.5) * 0.005
  });

  const getScatteredLoc = () => {
    const base = generalLocations[Math.floor(Math.random() * generalLocations.length)];
    return {
      lat: base.lat + (Math.random() - 0.5) * 0.04,
      lng: base.lng + (Math.random() - 0.5) * 0.04
    };
  };

  const availableSkills = [
    "Animal Care / Veterinary", "Carpentry", "Child Care", "Community Outreach", "Cooking",
    "Counseling", "CPR", "Crisis Communication", "Data Entry", "Debris Removal",
    "Driving", "Elderly Care", "Electrical Work", "Emergency Response", "Event Coordination",
    "Firefighting", "First Aid", "Fundraising", "Heavy Machinery Operation", "Inventory Management",
    "IT Support", "Legal Support", "Logistics", "Medical Assistance", "Mental Health Support",
    "Nursing", "Nutrition & Dietetics", "Photography / Videography", "Plumbing", "Radio Operation",
    "Search & Rescue", "Security Services", "Social Media Management", "Supply Distribution",
    "swimming", "Teaching", "Translation", "Water Purification"
  ];

  const adminSkills = ["Search & Rescue", "Medical Assistance", "Emergency Response", "Logistics"];
  const languagesList = ["English", "Hindi", "Punjabi", "Urdu", "Bengali", "Gujarati"];
  const ageRanges = ["18-30", "31-45", "46+"];
  const availabilityOptions = ["Full time", "Part time", "Weekends", "Evenings"];
  const servingAreas = ["Delhi NCR", "South Delhi", "Gurugram", "Noida", "Faridabad", "All over India"];

  async function clearCollection(collectionName) {
    console.log(`Clearing collection: ${collectionName}...`);
    const snapshot = await getDocs(collection(db, collectionName));
    const batch = writeBatch(db);
    let count = 0;
    
    if (collectionName === "reports") {
      for (const d of snapshot.docs) {
        const proofs = await getDocs(collection(db, "reports", d.id, "proofs"));
        proofs.forEach(p => batch.delete(p.ref));
        batch.delete(d.ref);
        count++;
      }
    } else {
      snapshot.forEach(d => {
        batch.delete(d.ref);
        count++;
      });
    }

    if (count > 0) {
      await batch.commit();
      console.log(`Deleted ${count} documents from ${collectionName}`);
    }
  }

  await clearCollection("reports");
  await clearCollection("users");
  await clearCollection("volunteer_applications");

  console.log("Generating Users (25 total)...");
  const usersData = [];
  const volunteerUIDs = [ADMIN_UID];
  const regularUIDs = [];

  const firstNames = ["Aarav", "Priya", "Rahul", "Sneha", "Vikram", "Neha", "Aditya", "Kavya", "Rohan", "Pooja", "Amit", "Anjali", "Karan", "Sonia", "Simran", "Arjun", "Kabir", "Meera", "Riya", "Yash", "Zoya", "Ishaan", "Tara", "Dev", "Myra"];
  const lastNames = ["Sharma", "Singh", "Verma", "Gupta", "Malhotra", "Reddy", "Desai", "Iyer", "Mehta", "Patel", "Kumar", "Joshi", "Bhatia", "Kapoor", "Das"];
  
  const generateRandomPhone = () => `+91${Math.floor(9000000000 + Math.random() * 999999999)}`;

  // Admin User
  usersData.push({
    uid: ADMIN_UID,
    name: "ReliefNet Admin",
    username: "admin_hero",
    email: "gmail@gmail.com",
    phone: "+919310543116",
    ageRange: "18-30",
    availability: "Full time",
    emergencyContactName: "Admin Primary",
    emergencyContactPhone: "+919310543116",
    fitness: "High",
    languages: ["English", "Hindi", "Punjabi"],
    servingArea: "Delhi NCR",
    isVolunteer: true,
    role: "admin",
    volunteerId: "100200300400",
    skills: adminSkills,
    notificationPrefs: { newReports: true, taskAssigned: true, taskCompleted: true, urgentOnly: false },
    updatedAt: Timestamp.now()
  });

  for (let i = 0; i < 24; i++) {
    const isVol = i < 14; // First 14 are volunteers
    const uid = generateId();
    
    if (isVol) volunteerUIDs.push(uid);
    else regularUIDs.push(uid);

    let selectedSkills = [];
    while (selectedSkills.length < 3) {
      let skill = availableSkills[Math.floor(Math.random() * availableSkills.length)];
      if (!selectedSkills.includes(skill)) selectedSkills.push(skill);
    }
    
    let selectedLangs = [languagesList[0]]; // English always
    if (Math.random() > 0.3) selectedLangs.push(languagesList[1]); // Hindi often

    let name = `${firstNames[i]} ${lastNames[i % lastNames.length]}`;

    usersData.push({
      uid: uid,
      name: name,
      username: name.split(" ")[0].toLowerCase() + Math.floor(Math.random() * 1000),
      email: `${name.replace(" ", ".").toLowerCase()}@example.com`,
      phone: generateRandomPhone(),
      ageRange: ageRanges[Math.floor(Math.random() * ageRanges.length)],
      availability: availabilityOptions[Math.floor(Math.random() * availabilityOptions.length)],
      emergencyContactName: `${name.split(" ")[0]}'s Family`,
      emergencyContactPhone: generateRandomPhone(),
      fitness: Math.random() > 0.5 ? "High" : "Medium",
      languages: selectedLangs,
      servingArea: servingAreas[Math.floor(Math.random() * servingAreas.length)],
      isVolunteer: isVol,
      volunteerId: isVol ? generateVolId() : null,
      role: isVol ? "volunteer" : "reporter",
      skills: isVol ? selectedSkills : [],
      notificationPrefs: { newReports: true, taskAssigned: isVol, taskCompleted: true, urgentOnly: false },
      updatedAt: Timestamp.now()
    });
  }

  console.log("Generating Applications (20 total)...");
  const applicationsData = [];
  applicationsData.push({
    id: generateId(),
    uid: ADMIN_UID,
    email: "gmail@gmail.com",
    name: "ReliefNet Admin",
    reason: "Overseeing all relief operations in the Delhi NCR area as the primary coordinator. I have a 4x4 vehicle ready for deployments.",
    skills: adminSkills,
    experience: "10+ years managing large scale NGO deployments during major crises.",
    status: "approved",
    volunteerId: "100200300400",
    appliedAt: randomDate(7, 5),
    approvedAt: randomDate(4, 2)
  });

  const appReasons = [
    "I want to help my local community during the monsoon season. I have a medical background and can provide first aid.",
    "Ready to deploy 24/7. I have a large truck that can be used for supply distribution and rescue.",
    "I am a licensed therapist and can provide mental health support to victims of the recent building collapse.",
    "I can cook for up to 500 people. I want to run a community kitchen for the displaced families.",
    "I'm young, fit, and ready to help clear debris and rescue trapped animals.",
    "I speak 4 languages and can help with translation and community outreach in the affected slum areas.",
    "I have experience setting up temporary shelters and tents from my time in the scouts.",
    "I am an electrician and can help secure exposed live wires in flooded neighborhoods."
  ];

  for (let i = 0; i < 19; i++) {
    let status = i < 9 ? "approved" : (i < 15 ? "pending" : "rejected");
    let userIndex = i < 9 ? i + 1 : Math.floor(10 + Math.random() * 10);
    let name = usersData[userIndex].name;
    let appUid = status === "approved" ? usersData[userIndex].uid : generateId();

    applicationsData.push({
      id: generateId(),
      uid: appUid,
      email: usersData[userIndex].email,
      name: name,
      phone: usersData[userIndex].phone,
      reason: appReasons[i % appReasons.length],
      skills: usersData[userIndex].skills || [availableSkills[Math.floor(Math.random() * availableSkills.length)]],
      experience: "Volunteered previously during the 2023 floods.",
      status: status,
      volunteerId: status === "approved" ? usersData[userIndex].volunteerId : null,
      appliedAt: randomDate(7, 3),
      approvedAt: status === "approved" ? randomDate(2, 0) : null
    });
  }

  console.log("Generating Reports (40 total)...");
  const reportsData = [];
  const proofsData = [];
  
  const scenarios = [
    { type: "Rescue Required", urgency: "High", desc: "Under-construction building collapsed in DLF Phase 3. 5 trapped under concrete.", skills: ["Search & Rescue", "Medical Assistance", "Emergency Response"], needs: ["Search & Rescue", "Ambulance"], cluster: GurgaonCluster, forceUnassigned: true },
    { type: "Rescue Required", urgency: "High", desc: "School bus stuck in severely waterlogged underpass near IFFCO Chowk.", skills: ["Search & Rescue", "Emergency Response", "Heavy Machinery Operation"], needs: ["Evacuation", "Transport Assistance"], cluster: GurgaonCluster, forceUnassigned: true },
    { type: "Shelter Assistance", urgency: "High", desc: "Basement completely flooded in Okhla Phase 2. 15 workers trapped.", skills: ["Search & Rescue", "Logistics"], needs: ["Evacuation", "Temporary Shelter"], cluster: OkhlaCluster },
    { type: "Medical Assistance", urgency: "High", desc: "Electric shock incident due to waterlogging in Okhla. Severe burns.", skills: ["First Aid", "Medical Assistance"], needs: ["First Aid", "Ambulance"], cluster: OkhlaCluster },
    { type: "Food Assistance", urgency: "High", desc: "Slum area near Okhla completely submerged. 200+ people stranded.", skills: ["Cooking", "Supply Distribution"], needs: ["Drinking Water", "Dry Rations"], cluster: OkhlaCluster },
    { type: "Water & Sanitation", urgency: "High", desc: "Sewer overflow mixing with main drinking water lines in Okhla.", skills: ["Water Purification", "Emergency Response"], needs: ["Drinking Water", "Water Purification"], cluster: OkhlaCluster },
    { type: "Rescue Required", urgency: "High", desc: "Wall collapsed near Okhla Estate. Families displaced.", skills: ["Search & Rescue", "Heavy Machinery Operation"], needs: ["Evacuation", "Doctor Required"], cluster: OkhlaCluster },
    { type: "Medical Assistance", urgency: "High", desc: "Laborers pulled from Gurugram building collapse with severe trauma.", skills: ["First Aid", "Counseling", "Nursing"], needs: ["First Aid", "Medicines"], cluster: GurgaonCluster },
    { type: "Utilities & Infrastructure", urgency: "High", desc: "Heavy machinery required to clear road block near Gurugram collapse site.", skills: ["Driving", "Electrical Work"], needs: ["Debris Clearing"], cluster: GurgaonCluster },
  ];

  const randomScenarios = [
    { type: "Food Assistance", urgency: "Medium", desc: "Daily wage workers in Noida Sector 62 need ration kits. Supply chain totally cut off.", skills: ["Cooking", "Logistics"], needs: ["Dry Rations", "Cooking Supplies"] },
    { type: "Medical Assistance", urgency: "Medium", desc: "Dengue cases spiking in Faridabad NIT. Distribution of nets needed.", skills: ["Medical Assistance", "Community Outreach"], needs: ["Medicines"] },
    { type: "Shelter Assistance", urgency: "Low", desc: "Community center in Dwarka needs roof patching before next monsoon cycle.", skills: ["Carpentry", "Logistics"], needs: ["Temporary Shelter"] },
    { type: "Utilities & Infrastructure", urgency: "Medium", desc: "Massive tree fallen on main road in Indirapuram.", skills: ["Debris Removal", "Driving"], needs: ["Debris Clearing"] },
    { type: "Food Assistance", urgency: "Low", desc: "Stray dogs starving in Central Delhi due to continuous rains.", skills: ["Animal Care / Veterinary", "Supply Distribution"], needs: ["Pet Food"] },
    { type: "Water & Sanitation", urgency: "Medium", desc: "Apartment complex water pump failed. 500 residents without water.", skills: ["Logistics", "Plumbing"], needs: ["Tanker Supply"] },
    { type: "Other", urgency: "Low", desc: "Need volunteers to help stack sandbags.", skills: ["Emergency Response", "Community Outreach"], needs: ["Sandbags"] },
    { type: "Medical Assistance", urgency: "High", desc: "Elderly person slipped on wet stairs and possibly fractured hip in Vasant Kunj.", skills: ["First Aid", "Medical Assistance"], needs: ["Ambulance"] },
    { type: "Shelter Assistance", urgency: "Medium", desc: "Tin roofs blown off 10 houses in Laxmi Nagar slum.", skills: ["Carpentry", "Supply Distribution"], needs: ["Temporary Shelter"] },
    { type: "Rescue Required", urgency: "High", desc: "Car swept away in flooded drain in Noida. Driver inside.", skills: ["Search & Rescue", "swimming"], needs: ["Search & Rescue", "Ambulance"] }
  ];

  // We need 40 total
  for (let i = 0; i < 40; i++) {
    let isCluster = i < 9;
    let scenario = isCluster ? scenarios[i] : randomScenarios[Math.floor(Math.random() * randomScenarios.length)];
    let loc = isCluster ? getClusterLoc(scenario.cluster) : getScatteredLoc();
    
    let status;
    let assignedVols = [];
    let submittedBy = regularUIDs[Math.floor(Math.random() * regularUIDs.length)];
    let currentReportId = generateId();

    if (scenario.forceUnassigned) {
      status = "unassigned"; 
    } else if (i < 5) {
      // 5 completed tasks for Admin to show massive impact
      status = "completed";
      assignedVols = [ADMIN_UID];
      proofsData.push({
        reportId: currentReportId,
        proofId: generateId(),
        data: {
          volunteerId: ADMIN_UID,
          timestamp: randomDate(2),
          imageUrl: "https://images.unsplash.com/photo-1593113512215-6bb0889ec6f1?q=80&w=600",
          note: "Successfully resolved the situation. All affected individuals are safe and evacuated. Handed over to local authorities."
        }
      });
    } else if (i >= 5 && i < 10) {
      // 5 Assigned/In Progress by Admin
      status = i % 2 === 0 ? "assigned" : "in_progress";
      assignedVols = [ADMIN_UID];
    } else if (i >= 10 && i < 15) {
      status = "unassigned"; 
      submittedBy = ADMIN_UID;
    } else {
      status = ["unassigned", "unassigned", "in_progress", "completed", "assigned"][Math.floor(Math.random() * 5)];
      if (status !== "unassigned") {
        assignedVols = [volunteerUIDs[Math.floor(Math.random() * volunteerUIDs.length)]];
        if (status === "completed" && Math.random() > 0.5) {
           proofsData.push({
            reportId: currentReportId,
            proofId: generateId(),
            data: {
              volunteerId: assignedVols[0],
              timestamp: randomDate(4),
              imageUrl: "https://images.unsplash.com/photo-1593113512215-6bb0889ec6f1?q=80&w=600",
              note: "Completed task as requested. Area secured."
            }
          });
        }
      }
    }

    reportsData.push({
      id: currentReportId,
      issueType: scenario.type,
      description: scenario.desc,
      immediateNeeds: scenario.needs || [],
      urgency: scenario.urgency,
      status: status,
      lat: loc.lat,
      lng: loc.lng,
      timestamp: randomDate(7, 3),
      resolvedAt: status === "completed" ? randomDate(2, 0) : null,
      resolutionNote: status === "completed" ? "Situation handled successfully. Required resources deployed." : null,
      submittedBy: submittedBy,
      assignedVolunteers: assignedVols,
      mediaUrls: [],
      aiSummary: {
        summary: `AI detects a ${scenario.urgency.toLowerCase()} urgency ${scenario.type} crisis requiring intervention.`,
        action_priority: scenario.urgency === "High" ? "Immediate" : (scenario.urgency === "Medium" ? "Within 24 hours" : "Within 72 hours"),
        estimated_people_affected: scenario.urgency === "High" ? "20-100" : "5-20",
        skillset_required: scenario.skills,
        solutions: [
          `Dispatch ${scenario.skills[0]} team to exact coordinates.`,
          `Secure ${scenario.needs ? scenario.needs[0] : "necessary resources"}.`,
          "Coordinate with local municipal authorities for backup."
        ]
      }
    });
  }

  console.log("Writing new highly-detailed demo data...");
  const batch = writeBatch(db);

  usersData.forEach(user => {
    const { uid, ...data } = user;
    batch.set(doc(db, "users", uid), data);
  });

  applicationsData.forEach(app => {
    const { id, ...data } = app;
    batch.set(doc(db, "volunteer_applications", id), data);
  });

  reportsData.forEach(report => {
    const { id, ...data } = report;
    batch.set(doc(db, "reports", id), data);
  });

  proofsData.forEach(proof => {
    const { reportId, proofId, data } = proof;
    batch.set(doc(db, "reports", reportId, "proofs", proofId), data);
  });

  await batch.commit();

  console.log("=========================================");
  console.log("✅ DONE! Ultimate Database tailored for demo video.");
  console.log(`Populated: ${usersData.length} Users, ${applicationsData.length} Apps, ${reportsData.length} Reports, ${proofsData.length} Proofs.`);
  console.log("=========================================");

})();
