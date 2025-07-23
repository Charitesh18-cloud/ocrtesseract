# 📄 Indic OCR Digitization App

A fully offline-capable mobile application for extracting, translating, and managing text from images and PDFs in over **12 Indic and international languages**.

---

## 🌟 Features

- 📷 **OCR for 12+ languages**: Hindi, Telugu, Tamil, Kannada, Malayalam, Urdu, Bengali, Gujarati, Odia, Marathi, Sanskrit, English.
- 🧠 **Tesseract OCR Integration**: Fast and accurate offline OCR using `flutter_tesseract_ocr`.
- ☁️ **Supabase Backend**: Secure email login, document storage, and history tracking.
- 🔐 **Passwordless Auth**: Email OTP-based authentication via Supabase.
- 🌐 **Translation**: Translate extracted text to any supported language (via FastAPI + NLLB or HuggingFace).
- 📁 **Document Management**: Save, delete, and restore documents. View history and trash.
- 🔤 **Language Tracker**: Keeps count of languages used in OCR.
- 🧑‍💼 **Profile Dashboard**: Stats like time spent, docs uploaded, words extracted.
- 👤 **Guest Mode**: Try the app without sign-up.

---

## 🛠️ Tech Stack

| Layer        | Tool/Library                        |
|--------------|-------------------------------------|
| UI           | Flutter                             |
| OCR Engine   | [flutter_tesseract_ocr](https://pub.dev/packages/flutter_tesseract_ocr) |
| Backend      | Supabase (Auth + DB + Storage)      |
| Storage      | Supabase Storage (for image/text)   |
| State Mgmt   | Local controllers, SharedPreferences|

---

## 📦 Installation & Running (Android Only)

### 🔧 Requirements

- Flutter SDK installed: https://docs.flutter.dev/get-started/install
- Android Studio or emulator/device
- Supabase project (see setup below)

### 🏃 How to Run the App

```bash
# Clone the repo
git clone https://github.com/Charitesh18-cloud/ocrtesseract.git
code . #for vs code setup

# Get packages
flutter pub get

# Run the app (Android only)
flutter run
```

---

## 🖼️ Assets Required

Ensure the following files are in `assets/` and configured in `pubspec.yaml`:

```yaml
assets:
    - assets/tessdata/tel.traineddata
    - assets/tessdata/eng.traineddata
    - assets/tessdata_config.json
    - assets/welcome.png
    - assets/ocr.png
    - assets/google_icon.png
    - assets/tessdata/asm.traineddata
    - assets/tessdata/ben.traineddata
    - assets/tessdata/guj.traineddata
    - assets/tessdata/hin.traineddata
    - assets/tessdata/kan.traineddata
    - assets/tessdata/mal.traineddata
    - assets/tessdata/mar.traineddata
    - assets/tessdata/nep.traineddata
    - assets/tessdata/ori.traineddata
    - assets/tessdata/pan.traineddata
    - assets/tessdata/san.traineddata
    - assets/tessdata/sin.traineddata
    - assets/tessdata/tam.traineddata     
```

---

## 🔧 Supabase Setup

- Create project on [https://supabase.com](https://supabase.com)
- Enable Email OTP login (passwordless)
- Create Tables:

### `profiles` Table

| Column             | Type    |
|--------------------|---------|
| id (PK)            | UUID    |
| name               | Text    |
| age                | Integer |
| preferred_language | Text    |
| usage_time         | Integer |

### `scans` Table

| Column               | Type    |
|----------------------|---------|
| id (PK)              | UUID    |
| user_id              | UUID    |
| document_url         | Text    |
| extracted_file_url   | Text    |
| extracted_lang       | Text    |
| translated_lang      | Text    |
| description          | Text    |
| created_at           | Timestamp |
| deleted              | Boolean |

---


---

## 📄 License

MIT License – free to use and modify.

---

## 🙏 Acknowledgements

- Tesseract OCR
- Supabase
- Hugging Face

---
