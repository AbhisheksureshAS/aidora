# 🚀 Aidora – Hyperlocal Help Platform

Aidora is a modern Flutter-based mobile application that connects people who need help with nearby verified helpers in real-time.

---

## 🎯 Overview

Aidora solves everyday problems by enabling users to:

- Find nearby helpers
- Post help requests
- Chat in real-time
- Complete tasks securely
- Build trust through ratings

---

## 👥 User Roles

### 🔹 Seeker
- Create help requests
- Browse nearby helpers
- Chat after request acceptance
- Mark tasks as completed
- Give ratings & reviews

### 🔹 Helper
- Accept/reject requests
- Provide services
- Build public rating & reputation

---

## ⚙️ Core Features

### 🔐 Authentication
- Firebase Email/Password login
- Secure session management

### 📍 Nearby Helpers
- Location-based discovery
- Distance calculation
- Skill-based filtering

### 📝 Help Requests
- Create task with category & urgency
- Track status: Pending → Accepted → Completed

### 💬 Chat System
- Real-time messaging
- Enabled only after request acceptance (security)

### ⭐ Rating System
- Public rating (stars + review)
- Private feedback via chat
- No duplicate ratings

### 🚨 Emergency Feature
- One-click emergency request
- High priority task creation

---

## 🛠️ Tech Stack

- **Flutter** (Frontend)
- **Firebase Auth** (Authentication)
- **Cloud Firestore** (Database)
- **Geolocator** (Location services)

---

## 📱 Screens

- Home
- Nearby Helpers
- Requests
- Chat
- Profile
- Rating

---

## 🔐 Security

- Firebase keys excluded using `.gitignore`
- Chat restricted until request acceptance
- Role-based permissions enforced

---

## 🚀 Getting Started

```bash
git clone https://github.com/AbhisheksureshAS/aidora.git
cd aidora
flutter pub get
flutter run









