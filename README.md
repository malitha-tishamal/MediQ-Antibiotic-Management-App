# 🏥 MediQ — Hospital Antibiotic Management & Analytics System

<p align="center">
  <img src="mediq/assets/logo/logo2.png" alt="MediQ Logo" width="120" />
</p>

<p align="center">
  <strong>A Secure, Cross-Platform Hospital Antibiotics Lifecycle Management & Usage Analytics System</strong><br>
  <em>Designed for Healthcare Facilities in Collaboration with National Hospital Karapitiya, Sri Lanka.</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.35.4-02569B?logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-3.9.2-0175C2?logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Firebase-Auth%20%7C%20Firestore-FFCA28?logo=firebase&logoColor=black" alt="Firebase" />
  <img src="https://img.shields.io/badge/Architecture-MVC-8A2BE2" alt="MVC Architecture" />
  <img src="https://img.shields.io/badge/Platforms-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Desktop-brightgreen" alt="Platforms" />
  <img src="https://img.shields.io/badge/Security-.env%20Protected-success" alt="Security" />
</p>

---

## 📖 Overview

**MediQ** digitises and streamlines the complete lifecycle of antibiotic distribution within hospital environments. It tracks antibiotics from initial receipt in the main store, through dispensing to clinical wards, handling returns of unused/expired medicines, and generating comprehensive analytical reports.

The system is architected to operate seamlessly alongside existing hospital paper records (BHTs and Ward Drug Order Books) while eliminating manual tracking discrepancies, stockouts, and medication expiration risks.

---

## ✨ Key Features

### 🔑 Role-Based Access & Governance
* **Admin Role**: System configuration, approval/disabling of pharmacist accounts, antibiotic & ward catalog management, inventory adjustments, and facility-wide analytics.
* **Pharmacist Role**: Dispensing antibiotics to wards, processing ward returns, querying book numbers, and inspecting live inventory.
* **Security & Approval Flow**: Self-registered accounts default to `Pending` status and cannot access application features until approved by a verified Administrator.

### 💊 Pharmacist Workflows
* **Release Antibiotics**: Dispense drugs to specific wards with atomic transaction-safe stock deductions from `main_stock`.
* **Return Antibiotics**: Accept returns from wards with automated quantity restock into `return_stock`.
* **Live Catalog & Ward Search**: Fast TypeAhead autocomplete search for antibiotics and hospital wards.
* **Digital Ward Order Tracking**: Record Book Numbers and Page Numbers corresponding to physical order books.

### 🛡️ Admin Management & Oversight
* **User Governance**: Approve, disable, update, or remove Admin and Pharmacist accounts with full audit tracking.
* **Antibiotic Catalog**: Add and maintain antibiotics with multi-dosage options and SR numbers.
* **Ward Registry**: Manage hospital wards, assigned units, and ward supervisors.
* **Store & Stock Control**: Real-time monitoring of Main Store and Return Store with low-stock alerts.
* **Data Exports**: Export inventory records and transaction logs to formatted **PDF Certificates** and **CSV Spreadsheets**.

### 📊 Advanced Usage Analytics
* **Visual Dashboards**: Powered by `fl_chart` for trend analysis, category distribution, and monthly releases vs. returns.
* **Ward-Wise Breakdown**: Detailed consumption metrics per hospital ward for antimicrobial stewardship.

---

## 🏛️ Architecture (Model-View-Controller)

MediQ is built on a clean, scalable **MVC** pattern with clear separation of concerns:

```
mediq/lib/
├── models/                       # [M] Strongly-Typed Domain Models
│   ├── user_model.dart           # UserModel, UserRole (Admin/Pharmacist), UserStatus
│   ├── antibiotic_model.dart     # AntibioticModel & DosageItem
│   ├── ward_model.dart           # WardModel (Hospital Wards)
│   ├── stock_model.dart          # StockItemModel (Main & Return Store items)
│   └── usage_record_model.dart   # UsageRecordModel (Release & Return records)
│
├── controllers/                  # [C] Business Logic & Database Transactions
│   ├── auth_controller.dart      # Authentication, Sign In/Up, Profile streams
│   ├── user_controller.dart      # Admin user management & status approvals
│   ├── antibiotic_controller.dart# Antibiotic catalog CRUD
│   ├── ward_controller.dart      # Ward catalog CRUD
│   ├── stock_controller.dart     # Stock queries & adjustments
│   └── usage_controller.dart     # Atomic transactions for Releases & Returns
│
├── views/                        # [V] Clean UI Layer
│   ├── auth/                     # Login, Registration, Forgot Password, Legal
│   ├── admin/                    # Admin dashboards, user management, analytics
│   ├── pharmacist/               # Dispensing, returning, usage history
│   └── dashboard/                # Shared dashboard screens & wrappers
│
├── services/                     # External Infrastructure
│   └── cloudinary_service.dart   # Secure image compression & Cloudinary CDN uploads
│
├── core/                         # Core Configurations
│   ├── app_config.dart           # Secure environment (.env) loader & fallbacks
│   └── firebase_options.dart     # Firebase multi-platform configuration
│
└── main.dart                     # App initialization & timezone configurations
```

---

## 🔒 Security & Environment Configuration

MediQ prevents secret leakage by isolating all API keys, Cloudinary upload credentials, and endpoints into environment configurations:

1. Credentials are loaded dynamically via `flutter_dotenv` at application startup.
2. All `.env` and sensitive credential files are strictly ignored in `.gitignore`.
3. A sanitized template file [`mediq/.env.example`](file:///e:/flutter/MediQ-Antibiotic-Management-App/mediq/.env.example) is provided for quick setup.

### Setting Up Environment Variables
Duplicate `.env.example` in the `mediq/` directory and name it `.env`:

```bash
cd mediq
cp .env.example .env
```

Populate `.env` with your actual credentials:
```env
# Cloudinary Configuration
CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_UPLOAD_PRESET=your_upload_preset

# Default Profile Images
CLOUDINARY_ADMIN_DEFAULT_URL=https://res.cloudinary.com/.../admin-default.jpg
CLOUDINARY_PHARMACIST_DEFAULT_URL=https://res.cloudinary.com/.../pharmacist-default.jpg
```

---

## 🚀 Getting Started

### Prerequisites
- **Flutter SDK**: `>= 3.0.0 < 4.0.0` (Recommended: `3.35.x` or later)
- **Dart SDK**: `>= 3.0.0`
- **Firebase Project**: Firestore Database + Firebase Authentication enabled
- **Git**

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/your-username/MediQ-Antibiotic-Management-App.git
   cd MediQ-Antibiotic-Management-App/mediq
   ```

2. **Configure Environment Variables**:
   Create a `.env` file inside `mediq/` as described above.

3. **Install Dependencies**:
   ```bash
   flutter pub get
   ```

4. **Run the Application**:
   ```bash
   # Android / iOS / Desktop / Web
   flutter run
   ```

5. **Build for Production**:
   ```bash
   # Android APK
   flutter build apk --release

   # Android App Bundle
   flutter build appbundle --release

   # Web
   flutter build web --release
   ```

---

## 🛠️ Tech Stack & Packages

| Category | Technology / Package | Purpose |
| :--- | :--- | :--- |
| **Framework** | [Flutter](https://flutter.dev) | Cross-platform UI development |
| **Language** | [Dart](https://dart.dev) | Type-safe language with sound null safety |
| **Backend & Database** | Firebase Firestore | Real-time NoSQL cloud database |
| **Authentication** | Firebase Auth | Email/Password authentication & account lifecycle |
| **Architecture** | MVC Pattern | Clean separation of Models, Views, and Controllers |
| **Charts & Graphs** | `fl_chart` | Interactive Line, Bar, and Pie analytics |
| **Search Autocomplete**| `flutter_typeahead` | Predictive search for antibiotics and wards |
| **Document Generation**| `pdf` & `printing` | Printable audit reports & certificates |
| **Data Export** | `csv` & `share_plus` | Spreadsheets export and sharing |
| **Image CDN** | Cloudinary & `http` | Profile photo upload & optimization |
| **Environment Config** | `flutter_dotenv` | Secure `.env` variable management |

---

## 👨‍💻 Developer & Credits

* **Lead Developer**: **Malitha Tishamal**  
  *Healthcare Software Developer*
* **Collaborating Hospital**: National Hospital Karapitiya, Sri Lanka

---

## 📄 License

This project is proprietary software developed for healthcare facility antibiotic management. All rights reserved.
