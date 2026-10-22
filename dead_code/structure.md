# Project Structure: PharmaGuide

## Overview
PharmaGuide is a Flutter-based pharmacy management application utilizing a feature-first architecture. It integrates Firebase for authentication and data storage, and Google ML Kit for OCR scanning of prescriptions.

## Core Architecture
The project follows a layered architecture within each feature:
- **Presentation**: UI screens, widgets, and state management via `Provider`.
- **Domain**: Business logic interfaces and domain models.
- **Data**: Repository implementations, data sources (Firestore/Local), and data models.

---

## Directory Map

### `lib/` (Application Root)
- `main.dart`: Entry point. Initializes Firebase and Provider graph.
- `app.dart`: Root widget and theme configuration.
- `firebase_options.dart`: Firebase configuration for different platforms.

### `lib/bootstrap/` (App Startup)
- `firebase_bootstrap.dart`: Handles asynchronous Firebase initialization.
- `splash_screen.dart`: Initial loading screen.
- `bootstrap_failure_screen.dart`: Error handling for startup failures.

### `lib/core/` (Cross-Cutting Concerns)
- `connectivity/`: Network status monitoring (`connection_source.dart`).
- `lifecycle/`: Base classes for resource management (`disposable_store.dart`).
- `navigation/`: Root shell for tab-based navigation (`app_shell.dart`).
- `theme/`: Global app styling and color palettes (`app_theme.dart`).
- `utils/`: Utility functions (e.g., `currency.dart` for Peso formatting).
- `widgets/`: Shared UI components used across multiple features.

### `lib/features/` (Domain Modules)
#### 🔐 `auth/` (Authentication)
- `data/`: `AuthRepository` and `OfflineSession` management.
- `presentation/`: `AuthProvider` and the `AuthLandingScreen`.

#### 📊 `dashboard/` (Main Hub)
- `presentation/`: `DashboardScreen` (Home tab), `ExpiringMedsScreen`, `NotificationsScreen` and their providers.
- `widgets/`: expiry-entry and stock sheets used by the Home tiles.

#### 🗃️ `inventory/` (Stock Management)
- `presentation/`: `InventoryScreen` for stock and expiry editing (admin).

#### 📦 `search/` (Medicine Catalogue)
- `data/`: `MedicineRepository`, `MedicineStore` (Firestore/Local), and `SyncStatus` logic.
- `presentation/`: `MedicineProvider` and `AttentionData` (calculates low stock/expiry).

#### 🛒 `orders/` (Sales & Basket)
- `data/`: `OrderHistoryRepository` and local order draft storage.
- `presentation/`: `OrderProvider` (basket state) and `OrdersScreen`.

#### 📈 `reports/` (Analytics)
- `data/`: `ReportsRepository` and models for sales/stock alerts.
- `presentation/`: `ReportsScreen` and dynamic analytics widgets.

#### 📷 `scan/` (OCR Processing)
- `data/`: `CameraPrescriptionCamera` and `MLKitTextRecognizer`.
- `domain/`: Interfaces for camera and recognition logic.
- `presentation/`: `ScanScreen` for live product matching.

#### 👤 `profile/` (User Settings)
- `presentation/`: `ProfileScreen` and appearance settings.

#### 💸 `sales/` (Checkout)
- `presentation/`: `NewSaleScreen` for processing transactions.

#### 🛡️ `admin/` (Admin Workspace)
- `data/`: `AuditRepository`, `UserRepository`.
- `presentation/`: `AdminHomeScreen`, `UsersScreen`, `UsersProvider`.

#### 🔎 `finder/` (Feature Finder)
- `data/`: `FeatureEntry`, `FeatureRepository`, static catalogue and route table.
- `presentation/`: `FinderScreen`, `FeatureSearchProvider`.

### `lib/routing/` (Navigation Graph)
- `app_router.dart`: Central GoRouter configuration, handling auth redirects and shell routing.

---

## Data Flow Pipeline
`UI Widget` $\rightarrow$ `Provider` $\rightarrow$ `Repository` $\rightarrow$ `Data Store (Firestore/Local)`

## Key Technologies
- **Framework**: Flutter / Dart
- **State Management**: Provider
- **Routing**: GoRouter
- **Backend**: Firebase Auth & Firestore
- **OCR**: Google ML Kit Text Recognition
- **Charts**: fl_chart
