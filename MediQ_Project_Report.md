# MediQ — Antibiotic Management App
## Fully Detailed Project Report

**Project Name:** MediQ  
**Version:** 1.0.0+1  
**Platform:** Flutter (Android, iOS, Web, Windows, Linux, macOS)  
**Backend:** Firebase (Firestore, Firebase Auth, Firebase Storage)  
**Collaborating Institution:** Karapitiya National Hospital  
**Developer:** Malitha Tishamal  
**SDK:** Dart ≥ 3.0.0 < 4.0.0  

---

## 1. Project Overview

MediQ is a cross-platform mobile/desktop application built with Flutter, designed specifically as an **Antibiotic Usage Analysis and Management System** for Karapitiya National Hospital. The app digitises and streamlines the entire antibiotic lifecycle — from pharmacist dispensing (releasing) and ward returns, through stock management, all the way to graphical usage analysis — replacing manual paper-based book systems while maintaining a link to them through a Book Numbers feature.

### Key Goals
- Digitise antibiotic release and return records per ward
- Provide real-time stock visibility (Main Store & Return Store)
- Enable role-based access for Administrators and Pharmacists
- Deliver graphical usage analysis (by antibiotic category and by ward)
- Maintain security through progressive account lockout and admin-approval workflows
- Support CSV data export for reporting

---

## 2. Technology Stack & Dependencies

| Category | Package | Version | Purpose |
|---|---|---|---|
| UI Framework | flutter | SDK | Core UI |
| Database | cloud_firestore | ^4.17.5 | NoSQL real-time database |
| Authentication | firebase_auth | ^4.20.0 | User login/session |
| File Storage | firebase_storage | ^11.7.7 | Profile image storage |
| Core Firebase | firebase_core | ^2.32.0 | Firebase initialization |
| Charts | fl_chart | ^0.66.0 | Usage analysis graphs |
| Timezone | timezone | ^0.9.2 | Sri Lanka (Asia/Colombo) time |
| Autocomplete | flutter_typeahead | ^5.2.0 | Antibiotic/Ward search |
| CSV Export | csv | ^5.0.1 | Data export |
| File Sharing | share_plus | ^7.2.0 | Share CSV reports |
| File Paths | path_provider | ^2.1.1 | Temp directory for exports |
| Image Picker | image_picker | ^1.2.0 | Profile photo upload |
| Image Compress | flutter_image_compress | ^2.3.0 | Optimize uploaded images |
| HTTP | http | ^1.1.1 | Cloudinary image upload |
| URL Launcher | url_launcher | ^6.2.0 | Open external links |
| Date Formatting | intl | ^0.19.0 | Date/time display |
| Preferences | shared_preferences | ^2.2.3 | Local storage |
| Toast | fluttertoast | ^8.2.1 | User feedback toasts |
| Icons | font_awesome_flutter | ^10.7.0 | Extended icon set |
| Icons | fluentui_system_icons | ^1.1.232 | Fluent UI icons |
| Icons | material_symbols_icons | ^4.2874.0 | Material symbols |
| Launcher Icons | flutter_launcher_icons | ^0.13.1 | App icon generation |

---

## 3. App Architecture

```
mediq/lib/
├── main.dart                     ← App entry point, AppColors, AuthWrapper
├── core/
│   ├── firebase_options.dart     ← Auto-generated Firebase config
│   ├── dashboard_screen.dart     ← Generic dashboard shell
│   └── dashboard_wrapper.dart   ← Role-based routing (Admin / Pharmacist)
├── auth/
│   ├── auth_wrapper.dart
│   ├── start_page.dart
│   ├── start_up_check_screen.dart
│   ├── firebase_load_check_screen.dart
│   ├── loading_start.dart
│   ├── login_page.dart
│   ├── signup_page.dart
│   ├── forgot_password_page.dart
│   └── user_agreement_page.dart
├── admin/
│   ├── admin_dashboard.dart
│   ├── admin_drawer.dart
│   ├── admin_profile_screen.dart
│   ├── admin_developer_about_screen.dart
│   ├── accounts-manage-details.dart
│   ├── antibiotics_management_screen.dart
│   ├── manage_antibiotics_screen.dart
│   ├── wards_management_screen.dart
│   ├── stocks_management_screen.dart
│   ├── book_numbers_screen.dart
│   ├── antibiotic_usage_screen.dart
│   ├── antibiotics_usage_analysis_screen.dart
│   ├── accounts/
│   │   ├── admin_accounts_manage.dart
│   │   └── pharmacist_accounts_manage.dart
│   ├── antibiotics/
│   │   ├── add_antibiotic_screen.dart
│   │   └── manage_antibiotics_screen.dart
│   ├── wards/
│   │   ├── add_ward_screen.dart
│   │   └── manage_wards_screen.dart
│   ├── usages/
│   │   ├── antibiotic_release.dart
│   │   └── antibiotic_return.dart
│   ├── stoks/
│   │   ├── main_store_screen.dart
│   │   └── return_store_screen.dart
│   └── analyst/
│       ├── antibiotics_analysis_screen.dart
│       ├── ward_wise_usage_screen.dart
│       ├── overall_summery.dart
│       ├── overall_usage overview/
│       │   ├── antibiotics_usage_charts_analysis.dart
│       │   ├── antibiotics_returns_charts_analysis.dart
│       │   ├── released_usage_summary.dart
│       │   └── return_usage_summary.dart
│       └── overall_usage_summery/
│           ├── released_usage_summary.dart
│           └── returned_usage_summary.dart
└── pharmacist/
    ├── pharmacist_dashboard.dart
    ├── pharmacist_drawer.dart
    ├── pharmacist_profile_screen.dart
    ├── pharmacist_developer_about_screen.dart
    ├── pharmacist_antibiotic_usage_screen.dart
    ├── pharmacist_book_numbers_screen.dart
    ├── view_antibiotics_screen.dart
    ├── view_wards_screen.dart
    ├── main_actions/
    │   ├── antibiotics_release_screen.dart
    │   └── return_antibiotics_screen.dart
    └── usages/
        ├── release_antibiotics_details.dart
        └── return_antibiotics_details.dart
```

---

## 4. Firebase Firestore Data Collections

| Collection | Purpose | Key Fields |
|---|---|---|
| `users` | All app accounts | `email`, `role`, `fullName`, `nic`, `mobileNumber`, `status`, `profileImageUrl`, `failedLoginAttempts`, `lockoutUntil`, `createdAt`, `updatedAt` |
| `antibiotics` | Antibiotic master list | `name`, `category`, `dosages[]` (each with `dosage`, `srNumber`), `createdAt`, `updatedAt` |
| `wards` | Hospital wards | `wardName`, `team`, `managedBy`, `category`, `description`, `createdAt`, `updatedAt` |
| `releases` | Antibiotic release records | `antibioticId`, `antibioticName`, `dosage`, `itemCount`, `wardId`, `wardName`, `stockType`, `bookNumber`, `pageNumber`, `releaseDateTime`, `createdBy`, `createdAt` |
| `returns` | Antibiotic return records | `antibioticId`, `antibioticName`, `dosage`, `itemCount`, `wardId`, `wardName`, `stockType`, `bookNumber`, `pageNumber`, `returnDateTime`, `createdBy`, `createdAt` |
| `main_stock` | Main Store stock levels | `antibioticId`, `dosageIndex`, `srNumber`, `drugName`, `dosage`, `quantity`, `lastUpdated` |
| `return_stock` | Return Store stock levels | Same structure as `main_stock` |

---

## 5. Global Design System (`AppColors`)

Defined in `main.dart` and overridden locally in each module:

| Token | Color | Use |
|---|---|---|
| `primaryPurple` | `#9F7AEA` / `#865AD9` | Primary accent, buttons, icons |
| `lightBackground` | `#F3F0FF` / `#F3F3FA` | Page background |
| `drawerBackground` | `#E2E7F3` | Side drawer |
| `buttonGradientStart` | `#9C27B0` | Button gradient start |
| `buttonGradientEnd` | `#673AB7` | Button gradient end |
| `headerGradientStart` | `#EB97E1` | Dashboard header gradient |
| `headerGradientEnd` | `#F7FAFF` | Dashboard header gradient |
| `adminsCountColor` | `#E53935` | Admin count indicator |
| `pharmacistCountColor` | `#43A047` | Pharmacist count indicator |
| `successGreen` | `#48BB78` | Success states |
| `warningOrange` | `#ED8936` | Warning states |

All buttons use a **purple-to-deep-purple linear gradient** with a soft drop shadow. All input fields use **rounded 10–12px borders** that turn purple when focused.

---

## 6. Authentication Module (`lib/auth/`)

### 6.1 App Startup Flow

```
StartUpCheckScreen
  └── FirebaseLoadCheckScreen (shows spinner while Firebase connects)
        └── AuthWrapper (StreamBuilder on FirebaseAuth.authStateChanges)
              ├── DashboardWrapper  (if logged in)
              └── LoginPage         (if not logged in)
```

- `StartUpCheckScreen` — Bootstraps timezone data (`Asia/Colombo`) and Firebase before the app shows any UI.
- `FirebaseLoadCheckScreen` — Displays a loading indicator while awaiting Firebase initialization.
- `auth_wrapper.dart` — Listens to Firebase auth state. Automatically routes authenticated users to the `DashboardWrapper` and unauthenticated users to `LoginPage`.

---

### 6.2 Login Page (`login_page.dart`)

**Screen Description:**  
A clean purple-themed login screen with the MediQ logo at the top, email and password fields, a "Forgot Password?" link, and a gradient "Login" button. A developer credit line is pinned to the bottom.

**Key Functions:**

| Function | Description |
|---|---|
| `_getLockoutDuration(int attempts)` | Returns lockout duration in seconds based on failed attempt count: 3 attempts=30s, 4=60s, 5=3min, 6=10min, 7=30min, 8+=permanent lock |
| `_getUserDocByEmail(String email)` | Queries Firestore `users` collection by email address, returns the matching document |
| `_recordFailedAttempt(String email)` | Increments `failedLoginAttempts` counter in Firestore; sets temporary `lockoutUntil` timestamp or permanently sets `status: Locked` if ≥8 failures |
| `_resetFailedAttempts(String email)` | Clears `failedLoginAttempts` and `lockoutUntil` fields on successful login |
| `_checkLockoutStatus(String email)` | Returns a record `{isLocked, message, lockoutEnd}` — checks if account is permanently locked (`status == Locked`) or temporarily locked (`lockoutUntil` in future) |
| `_startLockoutTimer()` | Starts a 1-second periodic timer that updates the countdown message visible to the user |
| `_updateLockoutMessage()` | Recalculates remaining lockout time and updates the displayed error message in real time (e.g., "Try again in 02m 45s") |
| `_handleLogin()` | Main login handler: validates inputs → checks lockout → calls Firebase `signInWithEmailAndPassword` → verifies `status == 'Approved'` → resets failed attempts → navigates to `DashboardWrapper` |
| `_buildGradientButton()` | Builds the gradient purple login button with box shadow; turns grey when disabled |
| `_buildInputField()` | Builds a styled text field with a left border separator icon, rounded corners, and purple focus border |
| `_buildPasswordInput()` | Same as above but with visibility toggle suffixIcon |

**Security Features:**
- Progressive lockout (30s → 1m → 3m → 10m → 30m → permanent)
- Account must have `status: Approved` to log in
- Incorrect email (user-not-found) does **not** record a failed attempt (prevents enumeration abuse)
- Real-time countdown timer shown during temporary lockout

---

### 6.3 Sign Up Page (`signup_page.dart`)

**Screen Description:**  
A scrollable registration form with the MediQ logo, role selector (Admin/Pharmacist), and fields for NIC, Full Name, Email, Mobile, Password, Confirm Password.

**Key Functions:**

| Function | Description |
|---|---|
| `_getDefaultProfilePicture()` | Loads the correct default profile image from assets based on selected role (admin-default.jpg / pharmacist-default.jpg), encodes it as Base64 string |
| `_validatePasswordMatch()` | Live listener that triggers form re-validation whenever password or confirm-password fields change |
| `_handleSignUp()` | Main register handler: validates form → loads default profile picture → creates Firebase Auth user → writes Firestore `users` document with `status: Pending` → shows success dialog |
| `_handleAuthError()` | Maps Firebase error codes (weak-password, email-already-in-use, invalid-email, network-error) to user-friendly messages |
| `_showSuccessDialog()` | Displays a styled success modal with animated icon, confirmation text, and "Continue to Login" button |
| `_validateNIC()` | Validates Sri Lankan NIC: accepts old format (9 digits + V/X) or new format (12 digits) |
| `_validatePassword()` | Requires minimum 6 characters |
| `_validateConfirmPassword()` | Checks both password fields match |
| `_buildRoleDropdown()` | Styled dropdown for Admin/Pharmacist selection with icons |
| `_buildGradientButton()` | Animated gradient button with loading spinner state |

**New Account Flow:**
- New accounts are always created with `status: Pending`
- Admin must approve them before login is allowed

---

### 6.4 Forgot Password Page (`forgot_password_page.dart`)

**Screen Description:**  
Simple email input page with logo. Sends a Firebase password-reset link to the entered email.

**Key Functions:**

| Function | Description |
|---|---|
| `_sendResetEmail()` | Calls `FirebaseAuth.sendPasswordResetEmail()`, handles `invalid-email` and `user-not-found` errors, displays success/error inline |
| `_buildGradientButton()` | Animated gradient button (same style as login) |

---

### 6.5 User Agreement Page (`user_agreement_page.dart`)

Standalone page displaying the app's terms and conditions / usage agreement that new users must review.

---

## 7. Core Module (`lib/core/`)

### 7.1 Dashboard Wrapper (`dashboard_wrapper.dart`)

This is the **central role-routing component** of the app. After login, all users land here.

**How it works:**
1. Gets the current Firebase authenticated user
2. Opens a real-time Firestore `StreamBuilder` on the user's document
3. Reads the `role` field from Firestore
4. Routes to `AdminDashboard` (role == `Admin`) or `PharmacistDashboard` (role == `Pharmacist`)
5. Extracts first name only from `fullName` for a friendly greeting

**Handles:** Loading states, error states, missing role errors gracefully.

---

### 7.2 Firebase Options (`firebase_options.dart`)

Auto-generated by FlutterFire CLI. Contains platform-specific Firebase project configurations (API keys, app IDs, project IDs) for Android, iOS, and Web.

---

## 8. Admin Module (`lib/admin/`)

The Admin module is the full management portal. Admins have access to all features: account management, antibiotic/ward CRUD, stock management, usage records, and analytics.

---

### 8.1 Admin Dashboard (`admin_dashboard.dart`)

**Screen Description:**  
A gradient header showing the admin's profile avatar, name, and "Administrative Dashboard" title, followed by a 2-column grid of quick-access tiles. A "Developed By Malitha Tishamal" bar is pinned at the bottom.

**Key Functions:**

| Function | Description |
|---|---|
| `_getSriLankaNow()` | Returns current datetime in Sri Lanka timezone (`tz.TZDateTime.now(tz.local)`) |
| `_getUtcStartOfToday()` | Converts Sri Lanka midnight to UTC for Firestore date queries |
| `_getUtcEndOfToday()` | Converts Sri Lanka 23:59:59.999 to UTC |
| `_getUtcStartOfCurrentMonth()` | Converts Sri Lanka 1st-of-month 00:00:00 to UTC |
| `_getUtcEndOfCurrentMonth()` | Converts Sri Lanka end-of-month 23:59:59.999 to UTC |
| `_listenToUserChanges()` | Firestore real-time listener on the logged-in user's document — updates avatar, name, role live |
| `_handleLogout()` | Signs out from Firebase Auth and navigates back to LoginPage, clearing the navigation stack |
| `_onNavTap(String title)` | Switch-case navigation: maps tile titles to their corresponding screens |
| `_buildDashboardHeader()` | Builds the pink→white gradient header with profile avatar, name, role, and drawer button |
| `_buildTilesGrid()` | Builds the 2-column GridView of navigation tiles |
| `_tileAccountsManage()` | Live tile — streams all users, counts Admins vs Pharmacists, shows live counts |
| `_tileAntibiotics()` | Live tile — streams antibiotics collection, shows total count and category count |
| `_tileWards()` | Live tile — streams wards collection, shows total wards and category count |
| `_tileSimple()` | Static tile — shows Stock Types (hardcoded as "02") |
| `_tileUsageDetails()` | Live tile — streams releases and returns for current month (Sri Lanka time), shows monthly counts |
| `_buildSmallTile()` | Generic small navigator tile for Usage Analyst, Book Numbers, Profile, Developer About |

**Dashboard Grid (9 tiles):**
1. Accounts Manage — Admin + Pharmacist live counts
2. Antibiotics — Total antibiotic types + categories
3. Wards — Total wards + ward categories
4. Stocks — Stock types (02)
5. Usage Details — Current month's releases + returns count
6. Usage Analyst — Navigation to analysis section
7. Book Numbers — Manual book reference system
8. Profile Manage — User's own profile
9. Developer About — Developer contact / info

---

### 8.2 Admin Drawer (`admin_drawer.dart`)

A slide-out navigation drawer accessible from the hamburger menu. Shows profile avatar, full name, role, and a list of navigation links. Includes a Logout button at the bottom. Mirrors the same navigation options as the dashboard tiles.

---

### 8.3 Account Management (`admin/accounts/`)

#### `admin_accounts_manage.dart` — Manage Admin Accounts
#### `pharmacist_accounts_manage.dart` — Manage Pharmacist Accounts

**Screen Description:**  
Tabbed lists of all Admin / Pharmacist accounts. Each entry shows name, email, NIC, mobile, status badge (Pending / Approved / Locked), and action buttons.

**Key Functions (both files similar):**

| Function | Description |
|---|---|
| `_fetchAllUsers()` | Queries Firestore `users` filtered by role, real-time stream |
| `_approveUser(String uid)` | Sets `status: Approved` in Firestore — allows that user to log in |
| `_lockUser(String uid)` | Sets `status: Locked` — prevents login |
| `_deleteUser(String uid)` | Deletes the Firestore document (does not delete Firebase Auth user — noted as a limitation) |
| `_showUserDetailModal()` | Full-screen modal showing complete user profile, status, and all action buttons |
| `_buildStatusBadge()` | Renders colour-coded chip: green=Approved, orange=Pending, red=Locked |

**Account status values:** `Pending`, `Approved`, `Locked`

---

### 8.4 Antibiotic Management (`admin/antibiotics/`)

#### `add_antibiotic_screen.dart` — Add / Edit Antibiotic

**Screen Description:**  
A form screen for adding a new antibiotic or editing an existing one. Fields: Antibiotic Name, Category (dropdown), and one or more Dosage rows (each with a numeric value, unit dropdown, and SR Number).

**Key Functions:**

| Function | Description |
|---|---|
| `_loadAntibioticForEdit(String id)` | Fetches existing antibiotic from Firestore and populates all form fields, supporting editing mode |
| `_mapUnitToOption(String unit)` | Maps raw unit strings (e.g., "mg", "milligram") to the standardised full option string (e.g., "mg - Milligram") |
| `_parseDosage(String dosageStr)` | Uses regex `(\d+(?:\.\d+)?)\s*([a-zA-Z/%]+)` to extract numeric value and unit from stored dosage strings |
| `_addDosageField()` | Appends a new dosage row (with value, unit, SR number controllers) to `_dosageRows` list |
| `_removeDosageField(int index)` | Disposes and removes a dosage row by index |
| `_saveAntibiotic()` | Validates form, validates at least one dosage+SR filled, builds dosage list, then creates or updates Firestore document |
| `_clearForm()` | Resets all fields and replaces dosage rows with a single empty row |
| `_buildHeader()` | Header with back button, admin avatar, and "Add New Antibiotic" / "Edit Antibiotic" title |
| `_inputDecoration()` | Reusable styled InputDecoration builder — purple theme with rounded corners |

**Unit Options:**
`mg - Milligram`, `g - Gram`, `mcg - Microgram`, `U - Unit`, `IU - International Unit`, `mL - Milliliter`, `cc - Cubic Centimeter`, `IV - Intravenous`, `mg/kg - Milligram per Kilogram`

**Antibiotic Categories:**
`Access`, `Watch`, `Reserve`, `Other`  
(WHO AWaRe classification)

**Data Structure stored per antibiotic:**
```json
{
  "name": "Amoxicillin",
  "category": "Access",
  "dosages": [
    { "dosage": "250 mg - Milligram", "srNumber": "12345" },
    { "dosage": "500 mg - Milligram", "srNumber": "12346" }
  ],
  "createdAt": "Timestamp"
}
```

---

#### `manage_antibiotics_screen.dart` — Manage / Search Antibiotics

**Screen Description:**  
Searchable list of all antibiotics with category filter chips. Each card shows name, category badge, all dosages with SR numbers, and Edit / Delete buttons.

**Key Functions:**

| Function | Description |
|---|---|
| `_buildSearchAndFilter()` | Top bar with TextField search and category filter chips (All, Access, Watch, Reserve, Other) |
| `_filterAntibiotics()` | Client-side filtering by name (search) and by category chip |
| `_deleteAntibiotic(String id)` | Shows confirmation dialog then deletes from Firestore; also cleans up associated stock entries |
| `_buildAntibioticCard()` | Card showing name, category colour chip, dosage pills with SR numbers, Edit and Delete buttons |

---

### 8.5 Ward Management (`admin/wards/`)

#### `add_ward_screen.dart` — Add / Edit Ward

**Screen Description:**  
Form with fields for Ward Name, Managed By (Team), Managed By (Doctor's Name), Category (dropdown), and Description.

**Key Functions:**

| Function | Description |
|---|---|
| `_loadWardForEdit(String id)` | Pre-fills form fields from existing Firestore ward document |
| `_saveWard()` | Validates form, then either adds new ward or updates existing one in Firestore |
| `_clearForm()` | Resets all input fields and selected category |

**Ward Categories:**
`Pediatrics`, `Medicine`, `ICU`, `Surgery`, `Medicine Subspecialty`, `Surgery Subspecialty`

**Data stored per ward:**
```json
{
  "wardName": "3 & 5 (Surgical prof.)",
  "team": "Team A",
  "managedBy": "Dr. Fernando",
  "category": "Surgery",
  "description": "Any notice details",
  "createdAt": "Timestamp"
}
```

---

#### `manage_wards_screen.dart` — Manage / Search Wards

Searchable and category-filterable list of all wards. Each card shows name, team, doctor, category, description, and Edit / Delete buttons.

---

### 8.6 Stocks Management (`admin/stoks/`)

#### `main_store_screen.dart` — Main Store Stock

**Screen Description:**  
Full screen listing all antibiotics from the `antibiotics` collection, joined with their corresponding stock quantities from the `main_stock` collection. Shows an Overview card at the top (Total / In Stock / Low / Out of Stock counts). Supports search and CSV export.

**Stock Status Thresholds:**
- `Out of Stock`: quantity == 0
- `Low Stock`: quantity < 50
- `In Stock`: quantity ≥ 50

**Key Functions:**

| Function | Description |
|---|---|
| `_fetchCurrentUserDetails()` | Loads admin name and profile image for the header |
| `_exportToCSV()` | Fetches all stock entries, converts to CSV format (SR Number, Drug Name, Dosage, Quantity, Last Updated, Document ID), saves to temp file, shares via `Share.shareXFiles()` |
| `_updateQuantity(String stockId, int newQuantity)` | Sets the stock quantity to a fixed value |
| `_addQuantity(String stockId, int currentQuantity, int addAmount)` | Increments the stock quantity by the entered amount |
| `_createStockEntry(...)` | Creates a new document in `main_stock` collection when no stock record yet exists for that antibiotic+dosage |
| `_buildSummaryCard()` | Computes Total, In Stock, Low Stock, Out of Stock counts and renders overview card |
| `_buildStockItemCard()` | Renders a full stock card: drug name, status badge, SR number, dosage, current quantity, quantity input, Add/Update buttons, last-updated date |
| `_itemKey(antibioticId, dosageIndex)` | Generates unique key `"antibioticId_dosageIndex"` for mapping antibiotics to stock entries |
| `_getController(String key)` | Gets or lazily creates a TextEditingController for each stock item quantity input |

**The stock display merges two Firestore streams:**
- Stream 1: `antibiotics` collection (drug names + SR numbers)
- Stream 2: `main_stock` collection (quantities)

Each antibiotic's dosage variant is shown as a separate stock item.

---

#### `return_store_screen.dart` — Return Store Stock

Identical structure to Main Store Screen but uses the `return_stock` Firestore collection. Manages antibiotics returned from wards that are stored in the secondary return store.

---

### 8.7 Antibiotic Usage Module (`admin/usages/`)

#### `antibiotic_release.dart` — Release Records (Admin View)

**Screen Description:**  
A comprehensive list screen showing all antibiotic release records from the `releases` collection. Includes a search bar, category filter chips (All/Access/Watch/Reserve/Other), and an advanced filter bottom sheet.

**Key Functions:**

| Function | Description |
|---|---|
| `_fetchFilterData()` | Pre-loads all wards and antibiotics into memory for filter dropdowns and category map |
| `_showFilterPanel()` | Opens a `DraggableScrollableSheet` bottom sheet with ward filter dropdown, antibiotic filter dropdown, and a From/To date range picker (Sri Lanka timezone aware) |
| `_filterRelease(Map data)` | Applies all active filters simultaneously: search query, category, ward, antibiotic, and date range |
| `_getUserName(String userId)` | Fetches user's full name from Firestore with an in-memory cache (`_userNameCache`) to avoid repeated network calls |
| `_editRelease(String docId, int currentQuantity)` | Shows a dialog to edit the quantity of an existing release record |
| `_confirmDelete(String docId, String name)` | Shows a confirmation dialog before deleting a release record from Firestore |
| `_showDetailsModal(Map data, String docId)` | Full-screen card dialog showing: antibiotic name, stock type badge, dosage, quantity, ward, book number, page number, release time, "Released by" (resolved by userId), created at, document ID, with Edit and Delete action buttons |
| `_buildFilterChip()` | Renders coloured filter chip showing category name and count |
| `_buildCategoryFilterRow()` | Scans all visible release documents and counts per-category, renders the filter chip row |
| `_buildReleaseCard()` | Compact styled card with left colour border (based on antibiotic category), antibiotic name, ward, dosage, quantity, date/time, book number, stock type badge, record creator |

**Firestore fields displayed per release:**
- Antibiotic Name & Dosage
- Quantity (itemCount)
- Ward Name
- Book Number & Page Number
- Release DateTime
- Stock Type (Main Store / Return Store)
- Released By (resolved from user UID)
- Created At timestamp
- Document ID

---

#### `antibiotic_return.dart` — Return Records (Admin View)

Identical structure to `antibiotic_release.dart` but reads from the `returns` Firestore collection. Same filtering, search, category chips, detail modal, edit quantity, and delete functions — adapted for return records.

---

### 8.8 Book Numbers Screen (`book_numbers_screen.dart`)

**Screen Description:**  
Manages the mapping between the digital system and the hospital's manual antibiotic logbooks. Each book entry has a Book Number and optional notes. Enables quick reference when cross-checking paper records.

**Features:**
- Add new book number entries
- View list of all book numbers
- Delete entries
- Integrates with the release/return forms so pharmacists can record which book page was used

---

### 8.9 Usage Analysis Screen (`antibiotics_usage_analysis_screen.dart`)

The entry point to the analytics section. Shows two analyst blocks: **Antibiotic Overview Analysis** and **Ward-Wise Usage Analysis**, each navigating deeper into charts and summaries.

---

### 8.10 Antibiotics Usage Analyst (`admin/analyst/`)

#### `antibiotics_analysis_screen.dart` — Antibiotic-Level Analysis

**Screen Description:**  
A 2×2 grid of analysis cards, each with an image thumbnail, title, description, and real-time data preview. Tapping a card navigates to its detailed chart or summary screen.

**Four Cards:**

| Card | Navigates To | Description |
|---|---|---|
| Releases Overview Charts | `AntibioticsUsageChartsAnalysisScreen` | Graphical bar/pie charts of all antibiotic releases by category |
| Returns Overview Charts | `AntibioticsReturnsAnalysisScreen` | Graphical charts of all antibiotic returns by category |
| Releases Details Analyst | `ReleasedUsageSummaryScreen` | Full A–Z sortable tabular summary of all releases |
| Returns Details Analyst | `ReturnUsageSummaryScreen` | Full A–Z sortable tabular summary of all returns |

**Key Functions:**

| Function | Description |
|---|---|
| `_buildReleasesCard()` | StreamBuilder on `releases` — shows total release count, navigates to chart screen |
| `_buildReturnsCard()` | StreamBuilder on `returns` — shows total return count, navigates to chart screen |
| `_buildReleasesByWardCard()` | Joins releases + wards, computes top-5 ward release counts, navigates to summary screen |
| `_buildReturnsByWardCard()` | Same as above but for returns |
| `_buildAnalysisCard()` | Reusable card builder with image, title, description, left colour border, and custom child widget |

---

#### `antibiotics_usage_charts_analysis.dart` — Release Charts (63KB)

**Feature-rich chart screen showing:**
- Bar charts of releases grouped by antibiotic name
- Pie/donut charts by category (Access / Watch / Reserve / Other)
- Time-range filtering (weekly/monthly/yearly)
- Uses `fl_chart` package for all visualisations

---

#### `antibiotics_returns_charts_analysis.dart` — Return Charts (64KB)

Identical chart capabilities as above but for return data.

---

#### `released_usage_summary.dart` / `return_usage_summary.dart` — Detailed Summary Tables (59–74KB)

**Full breakdown screens featuring:**
- Sortable table of every release/return record
- Filters: date range, ward, antibiotic, category
- Summary statistics (total items, unique antibiotics, unique wards)
- CSV export functionality
- Pagination or infinite scroll through large datasets

---

#### `ward_wise_usage_screen.dart` — Ward-Wise Analysis

**Screen Description:**  
Analysis screen focused on per-ward antibiotic usage. Shows which wards consume the most antibiotics, allows comparison across wards, and breaks down by category.

**Features:**
- Dropdown to select a specific ward
- Bar charts comparing release/return counts per ward
- Top-N ward ranking list
- Integrates Firestore `releases` + `wards` collections

---

#### `overall_summery.dart` — Overall Summary

Aggregated dashboard showing hospital-wide antibiotic usage statistics, combining data from both releases and returns collections.

---

### 8.11 Admin Profile Screen (`admin_profile_screen.dart`) (41KB)

**Screen Description:**  
Full profile management screen for the admin. Displays and allows editing of all personal details.

**Features:**
- View current profile info (name, email, NIC, mobile, role)
- Upload new profile photo (via `image_picker` → compress → upload to Cloudinary via HTTP → save URL to Firestore)
- Edit full name and mobile number
- Change password (via Firebase Auth `updatePassword`)
- Real-time Firestore listener updates the header avatar live

---

### 8.12 Developer About Screen (`admin_developer_about_screen.dart`) (23KB)

**Screen Description:**  
Information page about the developer (Malitha Tishamal). Shows developer photo, contact details (email, GitHub etc.), and links to portfolio / social profiles via `url_launcher`.

---

## 9. Pharmacist Module (`lib/pharmacist/`)

Pharmacists have a focused, action-oriented interface. They can issue/return antibiotics, view the antibiotic and ward lists, check their own usage records, and manage their profile.

---

### 9.1 Pharmacist Dashboard (`pharmacist_dashboard.dart`)

**Screen Description:**  
Same gradient header / grid tile layout as the admin dashboard, but tailored for the Pharmacist role. Shows personal stats (your releases today, your returns today) rather than system-wide counts.

**Key Functions:**

| Function | Description |
|---|---|
| `_listenToUserChanges()` | Real-time Firestore listener on current user's doc — updates name and avatar live |
| `_getSriLankaNow()` | Sri Lanka timezone-aware current date |
| `_getUtcStartOfToday()` / `_getUtcEndOfToday()` | Day boundaries in UTC for Firestore queries |
| `_getUtcStartOfCurrentMonth()` / `_getUtcEndOfCurrentMonth()` | Month boundaries in UTC |
| `_handleLogout()` | Firebase sign-out → navigate to LoginPage |
| `_onNavTap(String title)` | Routes to: ReleaseAntibioticsScreen, ReturnAntibioticsScreen, ViewAntibioticsScreen, ViewWardsScreen, PharmacistAntibioticUsageScreen, PharmacistBookNumbersScreen, PharmacistProfileScreen, PharmacistDeveloperAboutScreen |

**Dashboard Grid (9 tiles):**

| Tile | Live Data |
|---|---|
| Antibiotics Release | Count of releases made by this pharmacist today |
| Antibiotics Returns | Count of returns made by this pharmacist today |
| Antibiotics | Total antibiotics + categories (system-wide) |
| Wards | Total wards + categories (system-wide) |
| Usage Details | This pharmacist's releases + returns for current month |
| Book Numbers | Manual book reference |
| Profile Manage | Own profile |
| Developer About | Developer info |

> **Key difference from admin:** The pharmacist's release/return tiles filter by `createdBy == currentUserId` so pharmacists only see their own activity counts.

---

### 9.2 Release Antibiotics Screen (`pharmacist/main_actions/antibiotics_release_screen.dart`) (42KB)

**Screen Description:**  
The primary action screen for pharmacists. A comprehensive form for recording a new antibiotic release to a ward.

**Form Fields:**
- Ward selection (typeahead dropdown from `wards` collection)
- Antibiotic selection (typeahead dropdown from `antibiotics` collection)
- Dosage selection (dropdown populated from selected antibiotic's dosage list)
- Quantity / Item Count
- Stock Type (Main Store `msd` / Return Store)
- Book Number (from `book_numbers` collection)
- Page Number
- Release Date & Time (picker, defaults to current Sri Lanka time)

**Key Functions:**

| Function | Description |
|---|---|
| `_fetchWards()` | Loads all wards into the typeahead source list |
| `_fetchAntibiotics()` | Loads all antibiotics into the typeahead source list |
| `_onAntibioticSelected()` | When an antibiotic is selected, populates the dosage dropdown with that antibiotic's available dosages and SR numbers |
| `_submitRelease()` | Validates all fields → writes to Firestore `releases` collection with: antibioticId, antibioticName, dosage, itemCount, wardId, wardName, stockType, bookNumber, pageNumber, releaseDateTime, createdBy (UID), createdAt |
| `_clearForm()` | Resets all selections back to empty state |

---

### 9.3 Return Antibiotics Screen (`pharmacist/main_actions/return_antibiotics_screen.dart`) (42KB)

Structurally identical to the Release screen but writes to the `returns` Firestore collection. The Release DateTime field becomes a Return DateTime field.

---

### 9.4 Release Details / Return Details (`pharmacist/usages/`)

#### `release_antibiotics_details.dart` (51KB)
#### `return_antibiotics_details.dart` (51KB)

**Screen Description:**  
Personal usage history screens. Each pharmacist can view only their own release or return records. Includes:
- Search by antibiotic name or ward
- Date range filtering
- Category filter chips
- Detailed card view for each record
- Full detail modal on tap
- Edit quantity and delete own records

These are the pharmacist-facing equivalents of the admin's `antibiotic_release.dart` / `antibiotic_return.dart` screens, but filtered to `createdBy == currentUserId`.

---

### 9.5 View Antibiotics Screen (`view_antibiotics_screen.dart`) (27KB)

**Read-only** list of all antibiotics in the system. Pharmacists can search, filter by category, and view dosage and SR number details. No edit/delete capability (admin-only).

---

### 9.6 View Wards Screen (`view_wards_screen.dart`) (28KB)

**Read-only** list of all wards with search and category filtering. Pharmacists can view ward name, team, doctor, and category, but cannot modify.

---

### 9.7 Pharmacist Antibiotic Usage Screen (`pharmacist_antibiotic_usage_screen.dart`) (16KB)

Combined view of this pharmacist's personal release and return activity. Shows summary statistics and provides navigation to the detailed release/return lists.

---

### 9.8 Pharmacist Book Numbers Screen (`pharmacist_book_numbers_screen.dart`) (28KB)

Same as the admin Book Numbers screen — allows pharmacists to view and reference book number entries when filling release/return forms.

---

### 9.9 Pharmacist Profile Screen (`pharmacist_profile_screen.dart`) (41KB)

Identical feature set to the Admin Profile Screen — view, edit, upload profile photo, and change password. Uses the same Cloudinary upload pipeline.

---

### 9.10 Pharmacist Developer About Screen (`pharmacist_developer_about_screen.dart`) (24KB)

Same as the admin version — developer information and contact links.

---

## 10. Security & Access Control

| Feature | Implementation |
|---|---|
| Role-based routing | `DashboardWrapper` reads Firestore `role` field and routes to correct dashboard |
| Account approval | New accounts set `status: Pending`; admin must set `status: Approved` before login is allowed |
| Progressive lockout | 3, 4, 5, 6, 7 failed attempts → temporary lockouts (30s to 30min); ≥8 attempts → permanent `Locked` status |
| Real-time lockout countdown | `Timer.periodic(1 second)` updates the error message with remaining lockout time |
| Session management | `FirebaseAuth.authStateChanges()` stream handles session persistence and auto-login |
| Data scoping | Pharmacist dashboards filter all queries by `createdBy == currentUserId` |
| Input validation | NIC format (old/new), email regex, mobile 10-digit format, minimum password length enforced on signup |

---

## 11. Data Flow Summary

```
Pharmacist → Release Antibiotics Screen
    ↓ Selects ward, antibiotic, dosage, quantity, stock type, book/page
    ↓ Submits form
    → Firestore: releases/{docId}
    
Admin → Antibiotic Release Records Screen
    ↓ Streams all releases with filters
    → Reads from: releases collection
    → Joins with: antibiotics (category), users (name)
    
Admin → Main Store Screen
    ↓ Streams antibiotics + main_stock
    → Merged view: each dosage variant shown with stock quantity
    ↓ Admin enters quantity and clicks Add/Update
    → Firestore: main_stock/{docId} updated
    
Admin → Usage Analyst
    ↓ Reads releases + returns + wards + antibiotics
    → fl_chart graphs rendered client-side
    → CSV export via share_plus
```

---

## 12. Assets Structure

```
assets/
├── logo/
│   ├── logo.png          ← Main app logo (used on login, signup, forgot-password)
│   └── logo2.png         ← Launcher icon source
├── developer/
│   └── developer_photo.png
├── accounts/
│   ├── admin-default.jpg
│   └── pharmizist-default.jpg
├── antibiotics/
│   ├── manage_antibiotic.jpg
│   └── add_antibiotic.jpg
├── wards/
│   ├── add-ward.png
│   └── manage-ward.png
├── stores/
│   ├── main_store.jpg
│   └── return_store.jpg
├── usages/
│   ├── release_details.png
│   └── return_details.jpg
└── analyst/
    ├── antibiotic-usage.jpg
    ├── ward-usage.jpg
    ├── all-usage.jpg
    └── cards/
        ├── antibiotics-overviews/
        │   ├── releases-all.jpg
        │   ├── returns-all.jpg
        │   ├── releases.jpg
        │   └── returns.png
        ├── ward-wise-overviews/
        │   ├── releases-all.jpg
        │   ├── returns-all.jpg
        │   ├── releases.jpg
        │   └── returns.jpg
        └── overviews-summery/
            ├── release-summery.png
            └── return-summery.png
```

---

## 13. File Size Summary (Key Files)

| File | Size | Role |
|---|---|---|
| `return_usage_summary.dart` | 74.1 KB | Most complex — full sortable summary with filters |
| `released_usage_summary.dart` | 74.4 KB | Same for releases |
| `return_usage_summary.dart` (ward) | 59.3 KB | Ward-level returns summary |
| `released_usage_summary.dart` (ward) | 59.3 KB | Ward-level releases summary |
| `antibiotics_returns_charts_analysis.dart` | 64.0 KB | Returns chart analysis |
| `antibiotics_usage_charts_analysis.dart` | 63.9 KB | Releases chart analysis |
| `antibiotic_release.dart` (admin) | 51.4 KB | Admin release records list |
| `antibiotic_return.dart` (admin) | 50.8 KB | Admin return records list |
| `release_antibiotics_details.dart` | 51.8 KB | Pharmacist personal releases |
| `return_antibiotics_details.dart` | 51.3 KB | Pharmacist personal returns |
| `admin_profile_screen.dart` | 41.2 KB | Admin profile management |
| `pharmacist_profile_screen.dart` | 41.2 KB | Pharmacist profile management |

---

## 14. Platform Support

| Platform | Status |
|---|---|
| Android | ✅ Primary target |
| iOS | ✅ Supported |
| Web | ✅ Supported (firebase.json configured) |
| Windows | ✅ Supported |
| Linux | ✅ Supported |
| macOS | ✅ Supported |

---

## 15. Feature Completeness Summary

| Feature | Admin | Pharmacist |
|---|---|---|
| Login / Logout | ✅ | ✅ |
| Account Registration | ✅ | ✅ |
| Forgot Password | ✅ | ✅ |
| Progressive Lockout | ✅ | ✅ |
| Account Approval | ✅ (approve others) | ❌ (awaits approval) |
| Profile Management | ✅ | ✅ |
| Profile Photo Upload | ✅ | ✅ |
| Antibiotic CRUD | ✅ | ❌ (read-only) |
| Ward CRUD | ✅ | ❌ (read-only) |
| Main Store Management | ✅ | ❌ |
| Return Store Management | ✅ | ❌ |
| Release Antibiotics | ✅ (via records) | ✅ (action) |
| Return Antibiotics | ✅ (via records) | ✅ (action) |
| View All Release Records | ✅ | Own only |
| View All Return Records | ✅ | Own only |
| Edit Release Quantity | ✅ | Own only |
| Delete Release Records | ✅ | Own only |
| Book Numbers | ✅ | ✅ (view) |
| Usage Analysis Charts | ✅ | ❌ |
| Ward-Wise Analysis | ✅ | ❌ |
| CSV Export | ✅ | ❌ |
| Manage Admin Accounts | ✅ | ❌ |
| Manage Pharmacist Accounts | ✅ | ❌ |
| Sri Lanka Timezone Support | ✅ | ✅ |
| Developer About | ✅ | ✅ |

---

*Report generated: April 2026 | MediQ v1.0.0+1 | Developed by Malitha Tishamal*
