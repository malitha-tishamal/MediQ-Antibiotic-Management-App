# 🚀 MediQ — Cross-Platform Hospital Antibiotics Management System

**MediQ** is a **Cross-Platform Hospital Antibiotics Management System** designed to handle **Release, Return, Stock Tracking, Analytics, and User Management** with a **Modern Role-Based Interface**.

It **digitises the entire antibiotic lifecycle** from **dispensing and returns** to **stock management and usage analytics**, while supporting **parallel operation with existing manual paper-based systems**. 💊🏥

---

# 📌 Platform & Technical Details

- 📱 **Platform**: Flutter  
- ☁️ **Backend**: Firebase (Firestore + Auth + Storage)  
- 📝 **Version**: **1.0.0+1**  
- 👨‍💻 **Developer**: **Malitha Tishamal**  
- 🏥 **Institution**: Hospitals Sri Lanka  
- ⚙️ **SDK**: Dart ≥ 3.0.0 < 4.0.0  
- 💻 **Supported Platforms**:  
  **Android | iOS | Web | Windows | Linux | macOS**

---

# 🎯 Key Goals

- 💊 **Digitise antibiotic release & return**
- 📦 **Real-time stock visibility**
- 🔑 **Role-based access for Admins & Pharmacists**
- 📊 **Graphical & Advanced usage analysis**
- 🛡️ **Security through progressive account lockouts & audit trails**

---

# 🔐 Security & Architecture

- 🛡 **Secure Authentication**  
  **Firebase Auth + Email/NIC verification + Admin Approved Login**

- ⏱ **Progressive Lockouts**  
  *(30s → Permanent)*

- 🔑 **Role-Based Access**
  - **Admin**: Full access (dashboards, wards, stock, users, analytics)
  - **Pharmacist**: Release/return actions, stock view

- ⚡ **Backend Services**
  - Firebase Firestore *(real-time updates)*
  - Firebase Storage *(attachments)*
  - Firebase Auth *(login)*

- 🧩 **Modular Architecture**
		auth/
		admin/
		pharmacist/

**Reusable components & scalable architecture**

---

# 🛠 Technical Stack

### 📱 Frontend
- **Flutter (Single codebase across all platforms)**

### ☁️ Firebase Services
- Firebase Auth  
- Firestore  
- Storage  

### 📊 Data Visualization
- **fl_chart** — Line, Bar, Pie Charts

### 🗂 Utilities & Packages

- **flutter_typeahead** — Autocomplete search  
- **http & url_launcher** — API & link handling  
- **intl** — Timezone-aware datetime  
- **fluttertoast** — Notifications  

### 🎨 Icons

- **font_awesome_flutter**
- **material_symbols_icons**
- **fluentui_system_icons**

---

# 🎨 UI / UX Design

- 🟣 **Material 3 Theme**  
Purple primary, gradient buttons & tiles  

- 🖼 **Dashboard Layout**  
9 interactive tiles, responsive design  

- ✨ **Animations**
- Smooth page transitions  
- Hover effects  
- Interactive charts  

- 🔍 **UX Features**
- Searchable tables  
- Filterable dropdowns  
- Auto-refresh streams  
- Confirmation dialogs  

---

# 👤 Admin App Sections & Functions

**Full Control: Users, Stock, Wards, Analytics**

## 🖥️ Dashboard

- Total Antibiotics 💊  
- Wards 🏥  
- Releases/Returns Today 📤📥  
- Pending Approvals 👤  
- Low Stock Alerts ⚠️  

**Interactive widgets with live updates**

---

## 👥 User Management

- ✅ Approve new users  
- ❌ Disable/Delete accounts  
- ⏱ Track failed logins & lockouts  
- 🔑 Assign roles & update permissions  
- 📝 Audit logs  

---

## 💊 Antibiotics Management

- Add/Edit/Delete antibiotics  
- Multi-dosage support  
- AWaRe classification  
- ⚠️ Stock threshold alerts  

---

## 🏥 Ward Management

- Add/Edit/Delete wards  
- Assign managers & pharmacists 👨‍⚕️  
- Ward-specific antibiotic usage reports 📊  

---

## 📦 Stock Management

- Main & Return Store views  
- Low stock & expiry alerts ⚠️  
- CSV / PDF exports  
- Stock history logs  

---

## 📤 Release & Return Logs

- Track all releases/returns with filters  
- Undo errors  
- Logs with user, date/time, ward  

---

## 📊 Analytics & Reporting

- Line / Bar / Pie charts  
- Exportable reports (CSV/PDF)  
- Trend analysis for stock planning  

---

## ⚡ Notifications & Alerts

- Toasts for stock alerts  
- Email push for critical events  
- Auto-disable expired items  

---

# 👨‍⚕️ Pharmacist App Sections & Functions

## 🖥️ Dashboard

- Today’s Releases 📤  
- Today’s Returns 📥  
- Low Stock Alerts ⚠️  

---

## 💊 Release Management

- Select antibiotic, dosage, ward, quantity  
- Confirm release & live stock updates  
- View release history  

---

## 📥 Return Management

- Record returns & notes for damaged/expired  
- Auto-update return stock  
- Ward-wise reports  

---

## 📦 Stock Overview

- Ward-specific stock  
- Low stock / expiry alerts  
- Search & filter  

---

## ⚡ Notifications & Alerts

- Toast confirmations  
- Low stock warnings  
- Expiry alerts  

---

## 📊 Reports

- Quick ward usage reports (PDF/CSV)  
- Trend overview of released/returned items  

---

## 🔧 Utilities

- Real-time stock updates  
- Search/typeahead for antibiotics & wards  

---

# ✨ Key Takeaways

- 🏥 **Streamlines hospital antibiotic management**
- 📈 **Real-time analytics & stock monitoring**
- 🎨 **Modern, intuitive UI with responsive dashboards**
- 🔐 **Secure, role-based, multi-platform system**
- ⚡ **Scalable & maintainable architecture**
- 📊 **Audit-ready system**

---

# 📱 Supported Platforms

- ✅ Android  
- ✅ iOS  
- ✅ Web  
- ✅ Windows  
- ✅ Linux  
- ✅ macOS  

---

# 👨‍💻 Developer

**Malitha Tishamal**  
**Healthcare Software Developer**

---

# 🏷️ Tags
#Flutter #Firebase #HealthcareTech #HospitalManagement
#UIUXDesign #CrossPlatform #Analytics #Security
#MediQ #AntibioticsManagement #DigitalHealth #HospitalTech
