# AI Tracking MAP - PharmaGuide

## Purpose
Structured tracking system for AI-assisted development of PharmaGuide Flutter app. Maps gaps, phases, tests, and feature status for consistent AI context and task tracking.

> The canonical gap registry is `docs/architecture.md` §10. This file tracks the
> same work and must agree with it; when the two disagree, fix this file.

---

## 1. GAP REGISTRY

Statuses mirror `docs/architecture.md` §10.

| Gap ID | Description | Related Code | Priority | Status |
|--------|-------------|--------------|----------|--------|
| **G1** | `firestore.rules` coverage | `firestore.rules` | High | Fixed, **not deployed** (see G9) |
| **G2** | Reports tab sales figures fabricated (`math.Random`) | `reports_repository_impl.dart` | High | **Fixed** |
| **G3** | Three widgets with zero call sites | `settings_screen.dart`, `dashboard_tile.dart`, `feature_placeholder.dart` | Medium | **Fixed** (deleted) |
| **G4** | Order history not live | `orders_provider.dart`, `orders_screen.dart` | Medium | **Fixed** |
| **G5** | `ReportsProvider` error without notify | `reports_provider.dart` | Medium | **Fixed** |
| **G6** | Offline banner tests skip when `Connectivity()` throws `MissingPluginException` | `offline_banner_test.dart` | Low | Open |
| **G7** | `README.md` described an app that no longer exists | `README.md` | Medium | **Fixed** |
| **G8** | Stray `assets/data/medicines_seed.json.bak` | `assets/data/` | Low | Open |
| **G9** | `firebase.json` has no `firestore` section (rules won't deploy) | `firebase.json` | High | Open |
| **G10** | Inert "coming soon" controls | inventory, expiring meds, admin home, profile | Low | Open |
| **D1** | Scan integration test needs a physical device | `scan_screen.dart`, camera/OCR code | High | Deferred |

---

## 2. PHASE TRACKER

| Phase | Status | Completed Deliverables | Remaining Work | Next Action |
|-------|--------|----------------------|----------------|-------------|
| **Phase 1** | DONE | Unblock compiler (99 errors → 0), `flutter analyze` clean | - | - |
| **Phase 2** | DONE | Delete ink stroke, simplify multi-candidate ML Kit | - | - |
| **Phase 3** | DONE | Wire and ship Reports feature | - | - |
| **Phase 4** | DONE | Remove `who`, wire up completion | - | - |
| **Phase 5** | DONE | Cleanup: warnings, root files, analyze/test | - | - |
| **Phase 5.4-5.6** | DONE | Test suite green: 334 pass, 0 fail (`flutter analyze` clean) | - | - |
| **Phase 6** | DONE | Dead-code deletion (`OrdersProvider` trim, 3 files) + doc corrections | - | - |
| **Phase D1** | Deferred | Scan integration test (needs physical device) | Rewrite camera + OCR flow | Await device |

---

## 3. FEATURE STATUS MATRIX

| Feature | Stack | Status | AI Tracking Items |
|---------|-------|--------|-------------------|
| **Auth** | Firebase Auth (email/password, Google, offline guest) + roles | Done | - |
| **Dashboard** | Firestore medicine store, notifications, expiring meds | Done | - |
| **Search** | Medicine catalogue + `MedicineProvider` | Done | No finder-style widget gap |
| **Orders** | `OrdersScreen` (stream) + `OrdersProvider.updateOrderStatus` | Done | G4 fixed; dead provider state deleted |
| **Sales** | `NewSaleScreen` + `OrderProvider` (cart) | Done | - |
| **Reports** | `ReportsProvider` reading real order history | Done | G2/G5 fixed; profit is an assumed 22% margin |
| **Inventory** | stock + expiry management (admin) | Done | G10 (bulk count inert) |
| **Admin** | admin workspace + users | Done | G10 (store settings, activity log inert) |
| **Scan** | ML Kit OCR + camera | In Progress | D1 (integration test, needs device) |
| **Finder** | `FeatureEntry` + `FeatureRepository` + static catalogue | Done | No widget tests (see §4) |
| **Core** | Navigation (go_router), theme, connectivity | Done | - |

---

## 4. TEST COVERAGE MAP

### ✅ Passing Tests (Green)
`flutter test` → **334 passing, 0 failing**. `flutter analyze` → **No issues found**.

| Test File | Pass Count | Notes |
|-----------|------------|-------|
| `medicine_catalog_test.dart` | 25 | Catalogue grouping, search, paging |
| `scan_screen_test.dart` | 15 | Scan flow with a fake recogniser |
| `orders_screen_test.dart` | - | Approve/reject + history, stream-based |
| `reports_provider_test.dart` | 10 | Sales/low-stock/expiry, error notification |
| `splash_test.dart` | 6 | Splash + bootstrap failure screen |
| `widget_test.dart` | - | Landing, login sheet, 3-tab shell, nav |
| `nav_alignment_test.dart` | - | Bottom-nav destinations match the shell |

### 📋 Test Gaps
- Scan integration test (D1) - needs a physical device
- End-to-end New Sale → Orders tab flow
- Reports widget tests - commented out with TODOs (`reports_test.dart:311`)
- `FirestoreMedicineStore` - no tests (only the fake store is exercised)
- Finder / feature-finder widget tests

---

## 5. NEXT PRIORITIES

1. **G9** - Add a `firestore` section to `firebase.json` so `firestore.rules` actually deploy.
2. **D1** - Scan integration test when a physical device is available (camera + ML Kit OCR flow).
3. **End-to-end** - New Sale → add items → Proceed → order appears on the Orders tab as "New".
4. **G10** - Implement or remove the inert "coming soon" controls (no PDF/CSV path exists).
5. **G8** - Delete `assets/data/medicines_seed.json.bak`.
6. **G6** - Revisit the offline-banner test skip.

---

## 6. TRACKING CONVENTIONS

- **Gap IDs** follow `docs/architecture.md` §10 (G1-G10), plus D1 for the deferred device test
- **Phase numbers** match the project's phase numbering (1-6, 5.4-5.6, D1)
- **Status**: DONE, Open, Deferred, Pending
- **Priority**: High (blocks user value), Medium (should fix), Low (nice to have)
- **Test colors**: ✅ Passing, ❌ Known failures, 📋 Gaps

---

## 7. QUICK REFERENCE

| Artifact | Location | Status |
|----------|----------|--------|
| Technical Spec | `PharmaProgram.md` | Reference baseline |
| Work State | `thecurrentworkstate` | Phase tracker + notes |
| Canonical gaps | `docs/architecture.md` §10 | Source of truth |
| This MAP | `ai_tracking_map.md` | **This file** - active tracking |
| Analyze Result | `flutter analyze` | No issues found |
| Test Result | `flutter test` | 334 pass, 0 fail |
| Branch / HEAD | `main` | commit `72dbe81` (not pushed) |

---

*Generated for AI-assisted tracking of PharmaGuide development. Update after each development session to maintain accurate AI context.*
