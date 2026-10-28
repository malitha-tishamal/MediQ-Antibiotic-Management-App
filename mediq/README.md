# MediQ — Flutter Application

This directory contains the main Flutter application source code for **MediQ** (Hospital Antibiotic Management & Analytics System).

For complete project documentation, system architecture (MVC), features, and screenshots, please refer to the [Root README.md](../README.md).

## Quick Setup

1. **Setup Environment**:
   ```bash
   cp .env.example .env
   ```
   Add your Cloudinary credentials and optional configuration to `.env`.

2. **Get Dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run Application**:
   ```bash
   flutter run
   ```

4. **Code Structure**:
   - `lib/models/`: Domain entities (`UserModel`, `AntibioticModel`, `WardModel`, `StockItemModel`, `UsageRecordModel`).
   - `lib/controllers/`: Business logic, Firebase Auth, and Firestore transactional operations.
   - `lib/views/`: UI components organized by role (`auth/`, `admin/`, `pharmacist/`, `dashboard/`).
   - `lib/services/`: External integrations (`CloudinaryService`).
   - `lib/core/`: Configuration loaders (`AppConfig`) and Firebase setup (`DefaultFirebaseOptions`).
