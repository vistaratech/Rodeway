# Privacy Policy for Rodeway

**Last updated:** October 22, 2026

**Rodeway** ("we", "our", or "us"), developed by **Vistara Tech**, is an AI-enhanced Augmented Reality (AR) navigation and smart turn indicator mobile application. This Privacy Policy describes how your information is handled when you use our mobile application.

---

## 1. Summary: Privacy by Design

- **No Account Required:** Rodeway does not require user account registration, passwords, or personal profile creation.
- **Ephemeral Processing:** Camera frames and real-time sensor data used for AR route projection and AI lane detection are processed strictly on-device in volatile memory and are **never** recorded, stored, or transmitted to external servers.
- **No Data Selling:** We do not sell, rent, or trade your personal or location data to third parties.

---

## 2. Information We Access and How We Use It

### A. Location Information (`ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`)
- **Purpose:** Required to provide accurate GPS turn-by-turn navigation, display your position on Google Maps, compute routing directions, and calculate the distance to upcoming turns for triggering turn indicators.
- **Background Location:** If enabled, location data is used during an active navigation session to provide continuous guidance and calculate proximity to turns even if the screen is locked or the app is minimized.
- **Retention:** Real-time coordinates are processed on-device and shared securely with the Google Navigation SDK to fetch directions. We do not store a permanent history of your travel routes on our servers.

### B. Camera (`android.permission.CAMERA`)
- **Purpose:** Used strictly to provide Augmented Reality (AR) navigation, projecting 3D guidance paths onto the live roadway view in front of your vehicle.
- **Processing:** Video frames are analyzed locally in real time on your device for AR tracking and lane detection. Video feeds and photos are **never** captured, recorded, saved, or uploaded to any cloud server.

### C. Bluetooth & Nearby Devices (`BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`)
- **Purpose:** Used solely to discover and establish a local Bluetooth Low Energy (BLE) connection with your vehicle's physical ESP32 Smart Indicator hardware module.
- **Usage:** Transmits binary turn commands (left/right signal triggers) based on upcoming route waypoints. No personal identifying information is transmitted over BLE.

---

## 3. Third-Party Services

Rodeway integrates third-party services that may collect information used to identify you in accordance with their respective privacy policies:

- **Google Maps Platform & Google Navigation SDK:**  
  Used to render map data, autocomplete place searches, and calculate navigation routes.  
  [Google Privacy Policy](https://policies.google.com/privacy)

---

## 4. Data Retention and Deletion Policy

### Account Deletion
Rodeway **does not have user accounts or login systems**. As an anonymous, account-free application:
- No user accounts, credentials, or personal profiles are stored on remote databases.
- You do not need to request an account deletion because no account exists.

### Local Data Deletion
All application settings (such as terms acceptance and cached preferences) are stored strictly locally on your Android device using `SharedPreferences`.
- To completely delete all data associated with Rodeway:
  1. Open your Android device **Settings** ➡️ **Apps** ➡️ **Rodeway**.
  2. Select **Storage & cache** ➡️ tap **Clear storage / Clear data**.
  3. Alternatively, uninstalling the application permanently deletes all local data immediately.

### Data Inquiries
If you have questions regarding data privacy or wish to request confirmation of data deletion, contact us at:  
📧 **info.vistaratech@gmail.com**

---

## 5. Children's Privacy

Rodeway is not directed to children under the age of 13. We do not knowingly collect personal identifiable information from children.

---

## 6. Changes to This Privacy Policy

We may update our Privacy Policy periodically. Any changes will be posted on this page with an updated revision date.

---

## 7. Contact Us

If you have any questions, concerns, or feedback regarding this Privacy Policy, please contact us:
- **Developer:** Vistara Tech
- **Email:** info.vistaratech@gmail.com
- **Repository:** https://github.com/vistaratech/Rodeway
