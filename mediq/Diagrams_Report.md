# MediQ Antibiotic Management App - Data Flow Diagrams (DFD) Report

This report outlines the **Data Flow Diagram (DFD) Level 0 (Context Diagram)** and **DFD Level 1 (Process Decomposition)** for the **MediQ Antibiotic Management System**, mapped exactly to the active Firestore collections and Firebase Authentication configurations.

---

## 1. DFD Level 0 (Context Diagram)

The Context Diagram defines the boundary of the **MediQ System**, showing the external entities that interact with it and the high-level inputs/outputs flowing to and from the system.

### External Entities:
1. **Admin**: The system administrator who manages accounts, hospital wards, antibiotic listings, main stock, and views reports.
2. **Pharmacist**: The pharmacist who logs book numbers, patient antibiotic releases, and return stock entries.
3. **Firebase Authentication Service**: An external provider that verifies security tokens and checks user credentials.
4. **Cloudinary Service**: An external CDN that processes and hosts user profile pictures.

```mermaid
graph TD
    %% Entities
    Admin["👤 Admin"]
    Pharmacist["🧑‍⚕️ Pharmacist"]
    FirebaseAuth["🔐 Firebase Auth Service"]
    Cloudinary["☁️ Cloudinary CDN API"]
    
    %% System Process
    System["🔄 0.0 MediQ Antibiotic Management System"]
    
    %% Admin Flows
    Admin -->|Login Credentials & Reg Info| System
    Admin -->|Ward & Antibiotic Metadata| System
    Admin -->|Account Control Requests| System
    Admin -->|Main Stock Inputs| System
    System -->|Dashboard Stats & Logs| Admin
    System -->|Verification Prompts| Admin
    
    %% Pharmacist Flows
    Pharmacist -->|Usage Details & Book Entries| System
    Pharmacist -->|Profile Images / Edits| System
    Pharmacist -->|Releases & Return Stock Info| System
    System -->|Usage Receipts / Reports| Pharmacist
    System -->|Profile Metadata| Pharmacist
    
    %% Firebase Auth Flows
    System -->|Verify credentials| FirebaseAuth
    FirebaseAuth -->|Auth token & status| System
    
    %% Cloudinary Flows
    System -->|Image raw binary| Cloudinary
    Cloudinary -->|Secure CDN Image URL| System

    style System fill:#9F7AEA,stroke:#333,stroke-width:2px,color:#fff
    style Admin fill:#E2E7F3,stroke:#333,stroke-width:1px
    style Pharmacist fill:#E2E7F3,stroke:#333,stroke-width:1px
    style FirebaseAuth fill:#EDF2F7,stroke:#333,stroke-width:1px
    style Cloudinary fill:#EDF2F7,stroke:#333,stroke-width:1px
```

---

## 2. DFD Level 1 (System Process Decomposition)

Level 1 breaks down the main system into specific processes, demonstrating how data flows between processes, external entities, and internal data repositories (Data Stores).

### Data Stores (Exact Firestore Collections):
* **D1: users** (`/users` collection) - User profiles, names, NIC, roles.
* **D2: wards** (`/wards` collection) - Registered hospital wards.
* **D3: antibiotics** (`/antibiotics` collection) - Registered antibiotic drugs details.
* **D4: book_numbers** (`/book_numbers` collection) - Tracking serial book numbers.
* **D5: main_stock** (`/main_stock` collection) - Master stock level logs.
* **D6: releases** (`/releases` collection) - Patient dosage release entries.
* **D7: return_stock** (`/return_stock` collection) - Returned inventory stock level tracking.
* **D8: returns** (`/returns` collection) - Logged returned item forms.

### Processes:
1. **1.0 Authenticate & Route User**: Handles sign-in, session status check, and redirects users to their appropriate dashboard wrappers based on roles.
2. **2.0 Manage User Accounts**: Admin-only controls for creating, updating, and disabling user profiles in the `users` store.
3. **3.0 Manage Wards & Antibiotics Inventory**: Admin controls for registering wards in `wards` and adding/editing listings in `antibiotics`.
4. **4.0 Manage Book Registers**: Validates and tracks serial book registers in the `book_numbers` store.
5. **5.0 Manage Stock Inventory**: Log details for master inventory adjustments in `main_stock`.
6. **6.0 Record Releases & Returns**: Pharmacist inputs patient releases to `releases` and processes returned stock logged in `returns` and `return_stock`.
7. **7.0 Compile Usage Statistics**: Collects data from the stores to generate charts, stock levels, and audit logs.
8. **8.0 Edit Profile Settings**: Users update profiles in `users` and upload pictures via the Cloudinary API.

```mermaid
graph TD
    %% Entities
    Admin["👤 Admin"]
    Pharmacist["🧑‍⚕️ Pharmacist"]
    FirebaseAuth["🔐 Firebase Auth Service"]
    Cloudinary["☁️ Cloudinary CDN API"]

    %% Data Stores
    D1[("💾 D1: users")]
    D2[("💾 D2: wards")]
    D3[("💾 D3: antibiotics")]
    D4[("💾 D4: book_numbers")]
    D5[("💾 D5: main_stock")]
    D6[("💾 D6: releases")]
    D7[("💾 D7: return_stock")]
    D8[("💾 D8: returns")]

    %% Processes
    P1["🔄 1.0 Authenticate & Route User"]
    P2["🔄 2.0 Manage User Accounts"]
    P3["🔄 3.0 Manage Wards & Antibiotics"]
    P4["🔄 4.0 Manage Book Registers"]
    P5["🔄 5.0 Manage Stock Inventory"]
    P6["🔄 6.0 Record Releases & Returns"]
    P7["🔄 7.0 Compile Usage Statistics"]
    P8["🔄 8.0 Edit Profile Settings"]

    %% Process 1.0 Flows
    Admin -->|Credentials| P1
    Pharmacist -->|Credentials| P1
    P1 -->|Auth Verification| FirebaseAuth
    FirebaseAuth -->|Verification Token| P1
    P1 -->|Fetch Role| D1
    D1 -->|Role Data| P1
    P1 -->|Dashboard Access| Admin
    P1 -->|Dashboard Access| Pharmacist

    %% Process 2.0 Flows
    Admin -->|New User Payload| P2
    P2 -->|Save Profile| D1
    D1 -->|Query Results| P2
    P2 -->|Success Response| Admin

    %% Process 3.0 Flows
    Admin -->|Ward / Drug details| P3
    P3 -->|Write Ward Info| D2
    P3 -->|Write Drug Info| D3
    D2 -->|Ward details| P3
    D3 -->|Drug details| P3
    P3 -->|Sync Notification| Admin

    %% Process 4.0 Flows
    Admin -->|Book Numbers Metadata| P4
    Pharmacist -->|Log Book Range| P4
    P4 -->|Write Book Info| D4
    D4 -->|Query Status| P4

    %% Process 5.0 Flows
    Admin -->|Stock Adjustment Logs| P5
    P5 -->|Write Main Stock| D5
    D5 -->|Current Stock levels| P5

    %% Process 6.0 Flows
    Pharmacist -->|Releases details & Returns| P6
    P6 -->|Write Release Record| D6
    P6 -->|Write Return Stock| D7
    P6 -->|Write Returns Logs| D8
    D6 -->|Ack| P6
    D7 -->|Ack| P6
    D8 -->|Ack| P6

    %% Process 7.0 Flows
    D6 -->|Release trends| P7
    D8 -->|Return logs| P7
    P7 -->|Usage Statistics| Admin
    P7 -->|Usage Statistics| Pharmacist

    %% Process 8.0 Flows
    Admin -->|Raw Profile Image| P8
    Pharmacist -->|Raw Profile Image| P8
    P8 -->|Upload Binary| Cloudinary
    Cloudinary -->|Secure URL| P8
    P8 -->|Save profile changes| D1
    D1 -->|Ack| P8
    P8 -->|Display Profile| Admin
    P8 -->|Display Profile| Pharmacist
```
