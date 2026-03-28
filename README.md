# PROTO-0 - Hyper-Local Ethical Help & Services Platform

A comprehensive Flutter mobile application that connects people who need quick help with verified helpers nearby in a safe, ethical, and transparent ecosystem.

## 🎯 Core Vision

PROTO-0 solves real-life micro-problems like:
- **Academic guidance** (project help, coding help, subject doubts)
- **Skill learning support** (language, design, tech basics)
- **Daily life assistance** (errands, small tasks)
- **Emergency support** (urgent help requests)
- **Community collaboration** and ethical service exchange

## 🏗️ Architecture

The platform focuses on:
- **Trust** through verification and rating systems
- **Verification** of helpers and their skills
- **Hyper-local matching** using location services
- **Ethical interaction** with reputation tracking
- **Ease of use** with intuitive UI/UX

## 👥 User Roles

### Helper (Service Provider)
- Create comprehensive profile with skills and expertise
- Set availability and service areas
- Accept or reject help requests
- Build rating & reputation through ethical service
- Earn recognition through badges and trust levels

### Seeker (Service Requester)
- Post detailed help requests with categories and urgency
- Browse nearby verified helpers
- Real-time chat with helpers
- Give ratings and feedback
- Track request status and history

## 📱 Features Implemented

### 🔐 Authentication
- Email/Password signup and login
- Modern tabbed interface with validation
- Secure Firebase authentication integration

### 🧑‍💼 Profile System
- Complete user profiles with photos
- Skills and expertise management
- Location-based services
- Bio and description
- Rating display and reputation tracking
- Helper availability toggle

### 📝 Help Request Module
- Create requests with title, description, and category
- Set urgency levels (Low, Medium, High)
- Auto-location fetching with manual override
- Optional offered amount
- Required skills specification
- Real-time request status tracking

### 📍 Hyper-Local Matching
- GPS-based location services
- Distance-based sorting and filtering
- Nearby helpers discovery
- Skill-based matching algorithms
- Adjustable search radius
- Real-time location updates

### 💬 Chat System
- Real-time messaging between helpers and seekers
- Message read status tracking
- Chat room management
- Message history and timestamps
- Image and location sharing (ready for implementation)

### ⭐ Rating & Ethical Reputation System
- Comprehensive rating criteria (Communication, Quality, Timeliness, Professionalism, Helpfulness)
- Multi-criteria evaluation with comments
- Ethical score calculation
- Trust levels and badges system
- User reputation tracking
- Public/private rating options

### 🔔 Notification System
- Real-time notifications for new requests
- Request status updates
- New message alerts
- Rating notifications
- Nearby helper alerts
- Urgent request notifications
- Notification preferences management

### 🎨 UI/UX Design
- Modern purple/ethical color theme
- Clean card-based layouts
- Minimal and intuitive interface
- Bottom navigation with Home, Requests, Chat, Profile
- Floating action buttons for quick actions
- Responsive design patterns

## 🛠️ Technical Stack

### Frontend
- **Flutter** - Cross-platform mobile development
- **Material Design 3** - Modern UI components
- **Provider** - State management

### Backend & Services
- **Firebase Authentication** - User authentication
- **Cloud Firestore** - Real-time database
- **Firebase Storage** - Image storage (ready for implementation)
- **Geolocator** - Location services
- **Google Maps** - Map integration (ready for implementation)

### Location & Maps
- **Geolocator** - GPS and location services
- **Geocoding** - Address resolution
- **Distance calculations** - Haversine formula implementation

### Real-time Features
- **Firebase Real-time Database** - Live updates
- **Stream-based updates** - Real-time chat and notifications
- **Cloud Functions ready** - For server-side logic

## 📁 Project Structure

```
lib/
├── main.dart                    # App entry point
├── theme/
│   └── app_theme.dart          # App theme and colors
├── models/
│   ├── user_model.dart         # User data model
│   ├── help_request_model.dart # Help request model
│   ├── chat_model.dart         # Chat and message models
│   ├── rating_model.dart       # Rating and reputation models
│   └── notification_model.dart # Notification models
├── screens/
│   ├── home_screen.dart        # Main navigation and home
│   ├── profile_screen.dart     # User profile management
│   ├── create_request_screen.dart # Help request creation
│   ├── requests_screen.dart    # Browse and manage requests
│   ├── nearby_helpers_screen.dart # Find nearby helpers
│   ├── chat_screen.dart        # Real-time messaging
│   ├── rating_screen.dart      # Rate helpers
│   └── signin.dart             # Authentication
├── services/
│   ├── location_service.dart   # Location-based services
│   └── notification_service.dart # Notification management
└── firebase_options.dart       # Firebase configuration
```

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (>= 3.10.8)
- Firebase project setup
- Android Studio / VS Code
- Firebase CLI (for deployment)

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd proto_zero
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Setup**
   - Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)
   - Enable Authentication (Email/Password)
   - Set up Cloud Firestore
   - Configure Firebase Storage (for images)
   - Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Place files in appropriate directories

4. **Run the app**
   ```bash
   flutter run
   ```

## 🔧 Configuration

### Firebase Configuration
Update `firebase_options.dart` with your Firebase project configuration.

### Location Services
Ensure location permissions are configured in:
- `android/app/src/main/AndroidManifest.xml`
- `ios/Runner/Info.plist`

### Maps Integration (Optional)
Add Google Maps API key for enhanced map features.

## 📋 Development Status

✅ **Completed Features:**
- User authentication and profiles
- Help request creation and management
- Hyper-local matching with location services
- Real-time chat system
- Rating and reputation system
- Notification system
- Modern UI/UX design

🔄 **Ready for Enhancement:**
- Google Maps integration
- Image sharing in chat
- Push notifications (FCM)
- Video calling integration
- Payment processing
- Advanced filtering options

## 🌟 Key Features Highlight

### Ethical Reputation System
- Multi-dimensional rating criteria
- Trust levels (Trusted Helper, Reliable Helper, Verified Helper)
- Badge system for achievements
- Ethical score tracking

### Smart Matching Algorithm
- Location-based proximity matching
- Skill compatibility checking
- Urgency-based prioritization
- Real-time availability tracking

### Real-time Communication
- Instant messaging between users
- Read receipts and delivery status
- Chat history and search
- Media sharing capabilities

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Firebase for backend services
- Flutter community for amazing tools and packages
- Material Design team for UI guidelines
- All contributors and testers

## 📞 Support

For support and questions:
- Create an issue in the repository
- Contact the development team
- Check the documentation and FAQ

---

**PROTO-0** - Building communities through ethical help and services. 🌟
