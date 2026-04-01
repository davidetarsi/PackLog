# <img src="assets/icon/app_icon_round.png" width="40" height="40" valign="bottom"> PackLog

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter Badge"/>
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart Badge"/>
  <img src="https://img.shields.io/badge/SQLite-07405E?style=for-the-badge&logo=sqlite&logoColor=white" alt="SQLite Badge"/>
  <img src="https://img.shields.io/badge/Riverpod-000000?style=for-the-badge&logo=dart&logoColor=white" alt="Riverpod Badge"/>
</p>

**PackLog** is a cross-platform mobile application (iOS/Android) engineered for the intelligent management of personal belongings across multiple properties and real-time trip tracking.

The app addresses a common logistical pain point: maintaining an accurate inventory of items when managing multiple residences or traveling frequently.

---

## 📱 Screenshots

<p align="center">
  <img src="screen_app/houses.png" width="22%" alt="Multi-House Home"/>
  &nbsp;&nbsp;
  <img src="screen_app/houses_trip.png" width="22%" alt="Transit View"/>
  &nbsp;&nbsp;
  <img src="screen_app/house_detail.png" width="22%" alt="Inventory Detail"/>
  &nbsp;&nbsp;
  <img src="screen_app/create.png" width="22%" alt="Create Item"/>
  <br><br>
  <img src="screen_app/new_trip.png" width="22%" alt="New Trip"/>
  &nbsp;&nbsp;
  <img src="screen_app/trips.png" width="22%" alt="Trips Overview"/>
  &nbsp;&nbsp;
  <img src="screen_app/trip_detail.png" width="22%" alt="Trip Details"/>
  &nbsp;&nbsp;
  <img src="screen_app/settings.png" width="22%" alt="Settings"/>
</p>

---

## ✨ Core Features

* 🏠 **Multi-Property Management (Houses):** Full CRUD with integrated geocoding via Geoapify, custom iconography, and real-time inventory analytics.
* 🎒 **Inventory Engine (Items):** Categorized cataloging (Clothes, Toiletries, Electronics, Misc) with dynamic state tracking ("Available" vs. "In Transit").
* ✈️ **Trip Planning (Trips):** Timeline-based logistics with automatic status calculation (Upcoming, Active, Completed) and dynamic packing checklists.
* 💾 **Disaster Recovery & Backup:** Physical SQLite DB export/import system featuring automated pre-import safety backups, post-import schema validation, and atomic rollbacks in case of data corruption.
* 🎨 **Enterprise UX/UI & i18n:** Adaptive Light/Dark/System themes, proprietary Design System, and full internationalization (it-IT, en-US) with zero hardcoded strings.

---

## 🏗 Architecture & Design Decisions (The "Why")

PackLog is engineered using a **Feature-First Architecture** combined with **Clean Architecture** principles. This ensures a strict separation of concerns and high testability.

### 1️⃣ Relational DB (Drift) vs. NoSQL (Hive/Isar)
While NoSQL offers faster prototyping, I opted for **Drift (SQLite)** to handle complex relational queries (joins between houses, items, and trips), ensure referential integrity via Foreign Keys (with cascade deletes), and maintain type-safe schema migrations.

### 2️⃣ Snapshot Pattern for Trips
When an item is added to a trip, the system creates an independent **Snapshot (TripItem)** instead of a simple reference.
> **Rationale:** Immutability ensures that if a user modifies or deletes the original item from a house weeks later, the historical data of past trips remains intact.

### 3️⃣ Physical Backup vs. JSON Serialization
The backup system performs a file-system level copy of the `.db` file.
> **Rationale:** Physical copying is significantly faster than JSON serialization for large datasets, eliminates parsing overhead, and leverages SQLite's native atomic transaction guarantees.

### 4️⃣ Post-Import Validation & Rollback
Since Drift performs lazy migrations, an incompatible imported database could lead to delayed runtime crashes. PackLog forces an immediate connection check (`SELECT 1`). If the schema mismatch is detected, the app performs a transparent rollback using the safety backup, ensuring system stability.

---

## 💻 Tech Stack (The "How")

* **Core:** Flutter 3.10+, Dart 3.10.4
* **State Management:** Riverpod 2.5 (Code generation via `riverpod_annotation` for isolated, auto-dispose providers).
* **Database:** Drift 2.22.1 (SQLite ORM).
* **Routing:** GoRouter 14.2 (Declarative routing with `StatefulShellRoute` support).
* **Immutability:** Freezed & JSON Serializable.
* **Network:** Http (Geoapify API integration).

---

## 🚀 Getting Started

### 📋 Prerequisites
* Flutter SDK 3.10+
* Dart 3.10.4+
* A [Geoapify](https://www.geoapify.com/) API Key.

### 🛠 Quick Start

1.  **Clone the repository**
    ```bash
    git clone [https://github.com/your-username/packlog.git](https://github.com/your-username/packlog.git)
    cd packlog
    ```

2.  **Install dependencies**
    ```bash
    flutter pub get
    ```

3.  **Environment Configuration**
    Create a `.env` file in the root directory:
    ```env
    GEOAPIFY_KEY=your_api_key_here
    ```

4.  **Code Generation**
    *Crucial for generating Drift tables, Freezed models, and Riverpod providers.*
    ```bash
    dart run build_runner build --delete-conflicting-outputs
    ```

5.  **Run the application**
    ```bash
    flutter run
    ```

---

## 🧪 Testing & Maintenance

The project is designed for **TDD (Test-Driven Development)**, utilizing Repository pattern abstractions (`HouseRepository`) to allow seamless mock injection.

A `DataIntegrityService` runs health checks at startup to detect and repair orphaned foreign keys or data inconsistencies.

---

## 📄 License
Distributed under the MIT License. See `LICENSE` for more information.
