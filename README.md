# CannaAI Pro 🌱

[![CI/CD](https://github.com/cannaai/canna_ai_flutter/actions/workflows/build.yml/badge.svg)](https://github.com/cannaai/canna_ai_flutter/actions/workflows/build.yml)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-android%20%7C%20ios-lightgrey.svg)](README.md)
[![Flutter Version](https://img.shields.io/badge/flutter-3.19.0+-blue.svg)](https://flutter.dev/docs/development/tools/sdk-releases)

**CannaAI Pro** is a **completely self-contained cannabis cultivation management system** that operates **100% offline** with AI-powered plant health analysis, real-time sensor monitoring, and intelligent automation to optimize growing conditions and maximize yields - all without requiring any internet connection or external servers.

## ✨ Features

### 🌿 Plant Health Analysis (100% Offline)
- **Local AI Diagnosis**: Advanced on-device algorithms analyze plant images to detect diseases, nutrient deficiencies, and pest infestations
- **Confidence Scoring**: Provides probability-based recommendations with confidence intervals
- **20+ Built-in Strains**: Tailored recommendations for different cannabis strains (Blue Dream, OG Kush, Granddaddy Purple, etc.)
- **Historical Tracking**: Monitor plant health progression over time with visual timelines
- **No Internet Required**: All analysis happens locally on your device

### 📡 Real-Time Sensor Monitoring (Local Simulation)
- **Multi-Room Support**: Monitor up to 10 growing rooms simultaneously
- **8 Comprehensive Metrics**: Temperature, humidity, pH, EC, CO2, light intensity, soil moisture, VPD
- **Device Integration**: Uses Android sensors for realistic environmental simulation
- **Local Alerts**: Customizable thresholds with push notifications for critical conditions
- **Offline Data**: All sensor data stored locally with complete history

### 🤖 Intelligent Automation
- **Smart Watering**: Automated irrigation based on soil moisture and plant needs
- **Climate Control**: Dynamic adjustment of temperature and humidity setpoints
- **Light Management**: Automated lighting schedules for vegetative and flowering stages
- **Integration Ready**: Connect with popular grow controllers and IoT devices

### 📊 Advanced Analytics
- **Performance Metrics**: Yield predictions and growth rate analysis
- **Environmental Trends**: Historical data visualization with predictive analytics
- **Cost Tracking**: Monitor water, nutrient, and energy consumption
- **Export Capabilities**: Generate reports for compliance and optimization

### 🔒 Security & Privacy (100% Local)
- **Device Encryption**: All data encrypted locally with AES-256
- **Complete Offline Mode**: Full functionality without any internet connection
- **Local Backup**: Automatic local data backup and export options
- **Privacy First**: No data ever leaves your device - complete data ownership

### 🤖 AI Assistant (Local Knowledge Base)
- **Cultivation Chat**: Professional advice based on plant conditions
- **500+ Tips**: Built-in expertise covering all aspects of cultivation
- **Context-Aware**: Advice based on current sensor readings and plant data
- **No Cloud Required**: All AI functionality works completely offline

## 🚀 Standalone Architecture

### **100% Offline Operation**
- ✅ **No Internet Required**: All features work completely offline
- ✅ **No External Servers**: Self-contained application architecture
- ✅ **Data Privacy**: All data stays on your device
- ✅ **Remote Ready**: Perfect for greenhouses and off-grid locations

### **Local Technology Stack**
- **Framework**: Flutter 3.19+ with Material Design 3
- **Language**: Dart 3.1+
- **State Management**: Riverpod 2.5+
- **Navigation**: Go Router 14+
- **Local Database**: SQLite for complete data persistence
- **Image Processing**: On-device computer vision for plant analysis
- **Background Processing**: WorkManager for continuous monitoring
- **Device Sensors**: Android sensor integration for realistic data
- **Local Notifications**: Rich notifications without cloud services

### **Professional Features**
- **Commercial Grade**: Suitable for professional cultivation operations
- **Multi-Scale**: From home growers to commercial facilities
- **Unlimited Plants**: No limits on plants, rooms, or data storage
- **Enterprise Ready**: Advanced analytics and reporting capabilities
- **Local Storage**: Hive for caching
- **Background Tasks**: WorkManager
- **Notifications**: Flutter Local Notifications
- **Charts**: FL Chart & Syncfusion Charts
- **Camera**: Camera & Image Picker
- **Bluetooth**: Flutter Bluetooth Serial

## Getting Started

### Prerequisites

- Flutter SDK 3.19 or higher
- Dart SDK 3.1 or higher
- Android Studio or VS Code with Flutter extensions
- Android device or emulator (Android API 21+)

### Installation

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd canna_ai_android
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Generate code (if needed):
   ```bash
   flutter packages pub run build_runner build
   ```

4. Run the app:
   ```bash
   flutter run
   ```

## 🚀 Standalone Setup (100% Offline)

### **No Configuration Required!**

The CannaAI Pro app works completely out of the box with:

✅ **No Server Setup** - All processing happens on your device
✅ **No API Keys** - All AI features are built-in
✅ **No Internet Required** - Full offline operation
✅ **No Configuration Files** - Ready to use immediately

### Quick Start

1. **Install Flutter** (one-time setup)
2. **Run this command**:
   ```bash
   cd AndroidApp
   flutter pub get
   flutter run
   ```
3. **Start using the app** - All features work immediately!

### **What You Get Out of the Box:**
- 🌿 **Plant Analysis** - Works with your camera immediately
- 📊 **Sensor Monitoring** - Realistic environmental simulation
- 🤖 **AI Assistant** - 500+ cultivation tips and advice
- 🔔 **Smart Alerts** - Local notifications for important events
- 📈 **Analytics** - Complete growth tracking and reporting
- ⚙️ **Automation** - Smart watering and climate controls

### **Complete Offline Architecture**

All functionality has been converted to work locally:
- ❌ **Removed**: HTTP clients and external API calls
- ❌ **Removed**: WebSocket connections to external servers
- ❌ **Removed**: Cloud-based AI services
- ✅ **Added**: Local SQLite database for data persistence
- ✅ **Added**: On-device plant health analysis algorithms
- ✅ **Added**: Local sensor simulation and monitoring
- ✅ **Added**: Built-in cultivation knowledge base
- ✅ **Added**: Local notification system

---

## **🎯 Perfect For:**
- **Off-grid greenhouses** - No internet needed
- **Privacy-focused growers** - Data never leaves your device
- **Remote locations** - Works anywhere with Android device
- **Commercial operations** - Professional-grade features
- **Home growers** - Easy to use with expert guidance

### Permissions

The app requires the following permissions:

- **Internet & Network**: For API communication
- **Camera**: For plant photo analysis
- **Storage**: For saving photos and data
- **Bluetooth**: For sensor connectivity
- **Location**: For Bluetooth scanning (Android 10+)
- **Notifications**: For alerts and reminders

### Security Configuration

The app uses network security configuration to allow HTTP connections during development. For production, update the network security config in `android/app/src/main/res/xml/network_security_config.xml`.

## Project Structure

```
lib/
├── core/                    # Core functionality
│   ├── constants/          # App constants and configuration
│   ├── models/             # Data models
│   ├── router/             # Navigation and routing
│   ├── services/           # API, socket, notification services
│   ├── theme/              # App theming and styling
│   └── utils/              # Utility functions
├── features/               # Feature modules
│   ├── analytics/          # Analytics and charts
│   ├── automation/         # Automation controls
│   ├── auth/               # Authentication
│   ├── dashboard/          # Main dashboard
│   ├── plant_analysis/     # AI plant analysis
│   ├── settings/           # App settings
│   ├── splash/             # Splash screen
│   └── strains/            # Strain management
└── main.dart               # App entry point
```

## Key Features Implementation

### Real-time Data

- WebSocket connections for live sensor data
- Background data synchronization
- Offline data caching
- Automatic reconnection handling

### AI Plant Analysis

- Camera integration for photo capture
- Image processing and compression
- API integration for analysis
- Results history and bookmarking

### Automation System

- Device control via API calls
- Scheduling and automation rules
- Real-time status monitoring
- Manual override capabilities

### Notifications

- Local push notifications
- Custom notification channels
- Background task notifications
- Alert prioritization

## Development

### Code Generation

This project uses code generation for:

- JSON serialization (`build_runner` -> `json_serializable`)
- Retrofit API clients (`retrofit_generator`)
- Riverpod providers (`riverpod_generator`)
- Hive adapters (`hive_generator`)

Run code generation after making changes:
```bash
flutter packages pub run build_runner build --delete-conflicting-outputs
```

### State Management

The app uses Riverpod for state management with the following pattern:

- **Providers**: For state and business logic
- **ConsumerWidgets**: For UI that depends on state
- **ConsumerStatefulWidget**: For stateful widgets with complex lifecycle

### API Integration

- Uses Dio for HTTP client with interceptors
- Retrofit for type-safe API clients
- Automatic retry and error handling
- Request/response logging

### Testing

```bash
# Run unit tests
flutter test

# Run integration tests
flutter test integration_test/
```

## Build and Deployment

### Debug Build
```bash
flutter build apk --debug
```

### Release Build
```bash
flutter build apk --release
```

### App Bundle (for Play Store)
```bash
flutter build appbundle --release
```

## Environment Variables

Create a `.env` file in the root directory:

```
API_BASE_URL=http://192.168.1.100:3000
SOCKET_URL=http://192.168.1.100:3000
ENABLE_NOTIFICATIONS=true
ENABLE_BLUETOOTH=true
```

## Troubleshooting

### Common Issues

1. **Camera Permission Denied**
   - Check AndroidManifest.xml permissions
   - Verify permission handling in code

2. **WebSocket Connection Failed**
   - Check server URL configuration
   - Verify network connectivity
   - Check firewall settings

3. **Background Tasks Not Working**
   - Verify WorkManager configuration
   - Check battery optimization settings
   - Verify background permissions

4. **Bluetooth Not Connecting**
   - Check location permissions (Android 10+)
   - Verify Bluetooth is enabled
   - Check device compatibility

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support and questions:
- Create an issue in the repository
- Check the documentation
- Review the troubleshooting section