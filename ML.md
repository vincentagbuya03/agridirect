# Machine Learning (ML) & AI Technologies in AgriDirect

This document details all Machine Learning (ML) libraries, underlying AI models, and their exact use cases in the **AgriDirect** application.

---

## 📋 Summary of ML Stack

| ML Package | Underlying AI / Tech | Primary Use Case in AgriDirect |
| :--- | :--- | :--- |
| **`google_mlkit_text_recognition`** | **CRNN / CNN Deep OCR** (Google Vision) | Extracts Full Name, Sex, Birth Date, PCN, and Address from ID cards |
| **`google_mlkit_face_detection`** | **BlazeFace & Facial Landmark AI** | Liveness verification, oval selfie guide centering, and ID photo detection |
| **`google_mlkit_barcode_scanning`** | **Computer Vision 2D Matrix & JWT Decoder** | Scans PhilSys QR codes and decodes government cryptographic tokens |
| **`tflite_flutter`** | **TensorFlow Lite C++ Runtime** | Custom on-device neural networks (e.g., crop disease & agricultural AI) |
| **`mobile_scanner`** | **Native Camera Vision Stream** | High-performance barcode and QR scanning engine |

---

## 1. 🔤 Google ML Kit Text Recognition
- **Package**: `google_mlkit_text_recognition: ^0.15.1`
- **Model Architecture**: Convolutional Recurrent Neural Network (CRNN) with Connectionist Temporal Classification (CTC) trained on millions of document types.
- **Where it is used**:
  - `lib/mobile/screens/common/id_capture_screen.dart`
  - `lib/mobile/screens/auth/farmer_registration_screen.dart`
- **What it does**:
  1. Scans the front of Philippine National IDs, Driver’s Licenses, and Government IDs at 30 FPS.
  2. Extracts text blocks in real time to locate:
     - **Apelyido / Last Name**
     - **Mga Pangalan / Given Names**
     - **Gitnang Apelyido / Middle Name**
     - **Kasarian / Sex (Male / Female)**
     - **Petsa ng Kapanganakan / Date of Birth**
     - **16-digit PCN Number** (`XXXX-XXXX-XXXX-XXXX`)
     - **Address / Tirahan**
  3. Calculates the card's boundary coordinates to verify that the ID is **centered and inside the green guide box**.

---

## 2. 👤 Google ML Kit Face Detection
- **Package**: `google_mlkit_face_detection: ^0.13.2`
- **Model Architecture**: **BlazeFace** — Google’s ultra-fast mobile single-shot face detector optimized for sub-millisecond mobile inference.
- **Where it is used**:
  - `lib/mobile/screens/common/face_capture_screen.dart`
  - `lib/mobile/screens/common/id_capture_screen.dart`
- **What it does**:
  1. **Selfie Biometric Check**: Detects a live human face, tracks facial landmarks (eyes, nose, mouth), and ensures the face is properly centered inside the oval viewfinder.
  2. **Printed ID Photo Check**: Verifies that the front of the ID card contains a valid portrait photo.

---

## 3. 🏁 Google ML Kit Barcode & QR Scanner
- **Package**: `google_mlkit_barcode_scanning: ^0.14.2`
- **Model Architecture**: Binarized 2D Matrix Pattern Recognition with Reed-Solomon error-correcting algorithms.
- **Where it is used**:
  - `lib/mobile/screens/common/id_back_scanner.dart`
  - `lib/mobile/screens/auth/farmer_registration_screen.dart`
- **What it does**:
  1. Real-time stream detection of the PhilSys National ID back QR code.
  2. Automatically captures in **0.5s** once the QR code is recognized inside the frame.
  3. Decodes official government **JSON Web Tokens (JWT)** and JSON payloads to extract verified citizen identity records.

---

## 4. 🧠 TensorFlow Lite Runtime
- **Package**: `tflite_flutter: ^0.12.1`
- **Model Architecture**: Native TensorFlow Lite C++ bindings with Android NNAPI / GPU delegates.
- **Where it is used**:
  - Infrastructure ready for custom agricultural AI models (e.g. crop pest detection, leaf disease diagnosis, soil quality analysis).

---

## 5. ⚡ Why On-Device ML is Used in AgriDirect
1. **100% Offline Capability**: Farmers in rural fields with zero internet or weak 3G can still scan IDs and complete biometric KYC.
2. **Zero Latency**: Real-time 30–60 FPS video stream analysis without waiting for network uploads.
3. **$0 Cloud Costs**: All AI processing runs on the phone's hardware processor (CPU/GPU/NPU).
4. **Privacy & Security**: Sensitive KYC photos and biometrics are parsed locally on the device before encrypted submission to Supabase.
