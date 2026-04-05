# 📱 Hannah's TAC 368 Assignments
This repository contains multiple Flutter projects developed for TAC 368 (Cross Platform Application Development), including:
* Scrabble (two-computer networked game)
* Deal or No Deal
* Chatter (client/server messaging)
* Other assignments

## 🚀 How to Run

### General Setup

1. Clone the repository:
```bash
git clone <your-repo-url>
cd <repo-name>
flutter run
```
2. Install dependencies
```bash
flutter pub get
```

### Troubleshooting
For MacOS:
```bash
cd <repo-name>
cd macos/Runner/DebugProfile.entitlements
```
Add the line:
```bash
<key>com.apple.security.network.client</key>
<true/>
```
Then:
```bash
flutter clean
flutter run
```

## ⚙️ Tech Stack
Dart, Flutter
