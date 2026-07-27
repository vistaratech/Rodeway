# Rodeway 🚘✨
> **AI-Enhanced AR Navigation & Smart BLE Turn Indicator System**  
> 👨‍💻 **Developed by:** **[Yohesh Periyasamy](https://www.linkedin.com/in/yohesh-periyasamy-0529643a9/)**

[![LinkedIn](https://img.shields.io/badge/LinkedIn-0077B5?style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/yohesh-periyasamy-0529643a9/)
![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Unity](https://img.shields.io/badge/Unity-101010?style=for-the-badge&logo=unity&logoColor=white)
![TensorFlow](https://img.shields.io/badge/TensorFlow-FF6F00?style=for-the-badge&logo=tensorflow&logoColor=white)
![PyTorch](https://img.shields.io/badge/PyTorch-EE4C2C?style=for-the-badge&logo=pytorch&logoColor=white)
![ESP32](https://img.shields.io/badge/ESP32-E7352C?style=for-the-badge&logo=espressif&logoColor=white)
![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)


**Rodeway** is an advanced, next-generation navigation system that combines **Augmented Reality (AR)**, **Artificial Intelligence (AI)** computer vision for lane detection, and an **IoT ESP32 Smart BLE Indicator** for automated physical vehicle turn signaling.

---

## 🌟 Key Features

- **🚘 Immersive AR Navigation**: Renders real-time 3D route paths directly onto the camera view using Unity & ARCore.
- **🛣️ AI Lane Identification**: Real-time deep learning model (PyTorch / TensorFlow Lite) detecting and tracking lane positioning for safer driving.
- **💡 Smart Hardware Turn Indicators**: ESP32 microcontroller with Bluetooth Low Energy (BLE) automatically triggering physical LED turn lights on turns.
- **📱 Modern Flutter UI**: Intuitive, responsive mobile user interface with Google Maps & Mapbox integration.

---

## 🏗️ Project Architecture

The codebase is structured into four main components:

```
Rodeway/
├── lib/               # Flutter mobile application UI & business logic
├── unity/             # Unity project for 3D AR navigation & rendering
├── tflite/            # AI lane detection model (PyTorch training & TFLite export)
└── esp32_firmware/    # ESP32 BLE turn indicator firmware (.ino)
```

---

## 🚀 Getting Started

### Prerequisites

- **Flutter SDK**: `>= 3.0.0`
- **Android Studio / VS Code**: Android SDK API Level 34 (Android 14+)
- **Unity Engine**: `2022.2.3` (for AR build export)
- **Arduino IDE / CLI**: With ESP32 Board Package installed

---

### 1. Flutter Mobile App Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/vistaratech/Rodeway.git
   cd Rodeway
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Configure API Keys:**
   - Add your Google Maps API Key in `android/app/src/main/AndroidManifest.xml` and `lib/src/util/constants.dart`.

4. **Run the App:**
   ```bash
   flutter run
   ```

---

### 2. ESP32 BLE Indicator Setup

1. Open `esp32_firmware/rodeway_ble_indicator/rodeway_ble_indicator.ino` in Arduino IDE.
2. Select Board: **ESP32C3 Dev Module** (or any ESP32 variant).
3. Connect GPIO Pins:
   - `GPIO 2` ➡️ Right Turn Indicator LED
   - `GPIO 3` ➡️ Left Turn Indicator LED
4. Upload firmware to your ESP32 device.

---

### 3. Unity AR Integration (Optional for Custom AR Builds)

1. Open `/unity/cleadr` in **Unity 2022.2.3**.
2. Open `/Assets/Scenes/cleadr`.
3. Export to Flutter via: **Flutter ➡️ Export Android (Release)**.

---

## 🛠️ Tech Stack

| Domain | Technology |
|---|---|
| **Mobile App** | Flutter, Dart |
| **AR Engine** | Unity 3D, AR Foundation, ARCore |
| **Machine Learning** | PyTorch, ONNX, TensorFlow Lite (TFLite) |
| **Hardware / Firmware** | ESP32, C++, Bluetooth Low Energy (BLE) |
| **Mapping Services** | Google Maps SDK, Mapbox API |

---

## 👨‍💻 Developer

Developed with ❤️ by **[Yohesh Periyasamy](https://www.linkedin.com/in/yohesh-periyasamy-0529643a9/)** ([GitHub Profile](https://github.com/vistaratech)).


---

## 📄 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

