# PharmaGuide Technical Specification

## 1. High-Level Overview
- **Purpose:** Pharmacy management (Price list, Inventory, Sales, OCR Prescription Scanning).
- **Stack:** 
    - **Frontend:** Flutter
    - **State Management:** `provider`
    - **Navigation:** `go_router`
    - **Backend:** Firebase Auth (Identity) and Cloud Firestore (Data)
    - **Key Logic:** High-reliability offline-first sync for stock counts and orders.
    - **Currency:** Philippine Pesos (stored as `int` centavos to avoid floating-point errors).

## 2. Architecture Pattern
The project follows a strict **Layered Feature Architecture**:
`Presentation` $\rightarrow$ `Domain/Repository Interface` $\rightarrow$ `Data Implementation`

### Feature Folder Structure:
`lib/features/<feature_name>/`
- `data/`: 
    - `models/`: Plain Dart objects (no Flutter imports).
    - `repositories/`: Interface definitions and concrete implementations.
    - `sync/`: (Specific to search) Handles pending writes and sync status.
- `presentation/`:
    - `providers/`: `ChangeNotifier` classes for state.
    - `screens/`: UI views.
    - `widgets/`: Reusable UI components.

## 3. Core Module Map
| Module | Responsibility | Key Components |
| :--- | :--- | :--- |
| **Auth** | Identity & Session | `AuthProvider`, `FirebaseAuthRepository`, `OfflineSession` |
| **Search** | Price List & Catalog | `MedicineProvider`, `SeededMedicineStore` $\rightarrow$ `FirestoreMedicineStore` |
| **Dashboard** | Inventory & Alerts | `DashboardScreen`, `InventoryScreen`, `ExpiringMedsScreen` |
| **Orders** | Basket & History | `OrderProvider`, `OrderDraftStore`, `OrderHistoryRepository` |
| **Sales** | Transactional UI | `NewSaleScreen` |
| **Reports** | Analytics | `ReportsProvider`, `ReportsRepositoryImpl` |
| **Scan** | OCR Prescription | `PrescriptionRecognizer`, `MlKitTextRecognizer` |
| **Core** | Cross-cutting concerns | `AppShell` (Navigation), `AppTheme`, `ConnectionSource` |

## 4. Critical Technical Logic
### Offline-First Sync (The "Intersection" Trick)
The app implements a sophisticated 3-layer durability strategy for medicine stock counts:
1. **Firestore Cache:** Native disk persistence.
2. **`PendingWriteQueue`:** A secondary copy in `SharedPreferences` to prevent data loss if the native cache is evicted or the app is killed.
3. **Local Overlay:** Used for "Deliberate Offline Mode".

**Sync Workflow:** 
Writes are applied optimistically $\rightarrow$ Queued in `PendingWriteQueue` $\rightarrow$ Sent to Firestore. A write is only removed from the queue when a server snapshot arrives that confirms the change.

### Data Identity
- **Medicine Identity:** Defined by `(name, priceCentavos)`.
- **Document IDs:** Uses an FNV-1a hash of the name and price. This ensures that a price change creates a new record, while a stock change updates the existing one.

## 5. Key Constraints for Development
- **No Floating Point:** Never use `double` for money; always use `int` centavos.
- **No Direct Firestore in UI:** Presentation layers must never import `cloud_firestore`; they must communicate via Repositories.
- **Navigation:** Branch order in `app_router.dart` must strictly match `AppShell.destinations` indices.

## 6. Known Gaps (For AI to address)
- **G2:** Reports tab sales data is currently fabricated (`math.Random`); needs integration with `sales_seed.json`.
- **G4:** Order history is not live (uses a single sample instead of a stream subscription).
- **G10:** Export buttons (CSV/PDF) are placeholders and lack implementation.
