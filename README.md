# Moonfin

Jellyfin & Emby media client for mobile, TV, and desktop.

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel, 3.41+)
- [Git](https://git-scm.com/)

## Getting Started

```bash
# Clone the repo
git clone <repo-url>
cd Mobile-Desktop

# Install dependencies
flutter pub get
```

## Building for Windows

### Requirements

1. **Windows 10 or Windows 11**

2. **PowerShell 5.1+**
   - Included with modern Windows installations

3. **Git**
   - Install from [git-scm.com](https://git-scm.com/)

4. **Flutter SDK**
   - Stable channel, 3.41+
   - Either add `flutter` to `PATH` or install it at `C:\flutter\bin\flutter.bat`
   - Verify with:
     ```powershell
     flutter doctor -v
     ```

5. **Visual Studio 2022** (Community edition or higher)

6. The following Visual Studio workloads/components (install via Visual Studio Installer → Modify):
   - **Desktop development with C++** workload
   - **MSVC v142+ C++ x64/x86 build tools** (included in the workload)
   - **C++ CMake tools for Windows** (included in the workload)
   - **Windows 10 SDK** (10.0.19041.0 or later)
   - **C++ ATL for latest build tools** (required by `flutter_secure_storage`)

   You can also install these from an **elevated (Admin) PowerShell**:
   ```powershell
   & 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vs_installer.exe' modify `
     --installPath 'C:\Program Files\Microsoft Visual Studio\2022\Community' `
     --add Microsoft.VisualStudio.Workload.NativeDesktop `
     --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
     --add Microsoft.VisualStudio.Component.VC.CMake.Project `
     --add Microsoft.VisualStudio.Component.Windows10SDK.19041 `
     --add Microsoft.VisualStudio.Component.VC.ATL `
     --passive --norestart
   ```

7. **Inno Setup 6**
   - Install from [innosetup.com](https://jrsoftware.org/isinfo.php)
   - The build script auto-detects `ISCC.exe` from common install paths and registry entries

### One-time setup checklist

Run these checks before the first Windows build:

```powershell
flutter doctor -v
where flutter
```

Confirm these work:
- `flutter doctor -v` shows Windows desktop toolchain ready
- Visual Studio C++ desktop components are installed
- Inno Setup 6 is installed

### One-command full rebuild installer

From the repo root, run:

```powershell
.\build-windows.ps1
```

What this does:
- runs `flutter clean`
- runs `flutter pub get`
- builds Windows release
- builds the Inno Setup installer
  - reads the installer version automatically from `pubspec.yaml`
- copies the final installer to the repo root

Final outputs:
- Root copy: `Moonfin-Setup-x64.exe`
- Build copy: `build\windows\installer\Moonfin-Setup-x64.exe`

Generated during the build:
- `build\windows\installer\moonfin.generated.iss`

### Example release flow

```powershell
git pull
.\build-windows.ps1
```

After the script finishes, share or test:
- `Moonfin-Setup-x64.exe`

### Portable EXE only

```bash
flutter build windows --release
```

The output is a self-contained folder at:
```
build\windows\x64\runner\Release\
```
Copy the entire `Release` folder to distribute. Run `moonfin.exe` to launch.

### MSIX Installer (Optional)

```bash
flutter pub run msix:create
```

The `.msix` installer will be generated at:
```
build\windows\x64\runner\Release\moonfin.msix
```

## Building for Android

### Requirements

- [Android Studio](https://developer.android.com/studio) with Android SDK
- Android SDK Build-Tools, Platform-Tools, and an Android platform (API 21+)

```bash
flutter build apk --release       # APK
flutter build appbundle --release  # AAB (for Google Play)
```

Output:
- APK: `build/app/outputs/flutter-apk/app-release.apk`
- AAB: `build/app/outputs/bundle/release/app-release.aab`

## Building for iOS

### Requirements

- macOS with [Xcode](https://developer.apple.com/xcode/) installed
- Valid Apple Developer account (for device/distribution builds)
- CocoaPods: `sudo gem install cocoapods`

```bash
cd ios && pod install && cd ..
flutter build ios --release
```

For an IPA (distribution):
```bash
flutter build ipa --release
```

Output: `build/ios/ipa/moonfin.ipa`

## Building for macOS

### Requirements

- macOS with [Xcode](https://developer.apple.com/xcode/) installed
- CocoaPods: `sudo gem install cocoapods`

```bash
flutter build macos --release
```

Output: `build/macos/Build/Products/Release/moonfin.app`

## Building for Linux

### Requirements

- GCC, CMake, Ninja, pkg-config, GTK 3.0 development headers
- On Ubuntu/Debian:
  ```bash
  sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev
  ```

```bash
flutter build linux --release
```

Output: `build/linux/x64/release/bundle/` (run `moonfin` from within)

## Troubleshooting

- Run `flutter doctor -v` to diagnose missing dependencies for any platform.
- If you see a `RepeatMode` ambiguity error, ensure the Flutter material import hides it:
  ```dart
  import 'package:flutter/material.dart' hide RepeatMode;
  ```
- On Windows, if `atlstr.h` is missing, install the **C++ ATL** component via Visual Studio Installer.
