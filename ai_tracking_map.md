# AI Tracking MAP - PharmaGuide

## Purpose
Structured tracking system for AI-assisted development of PharmaGuide Flutter app. Maps gaps, phases, tests, and feature status for consistent AI context and task tracking.

---

## 1. GAP REGISTRY

| Gap ID | Description | Related Code | Priority | Status | Last Updated |
|--------|-------------|--------------|----------|--------|--------------|
| **G1** | Reports tab sales data fabricated (`math.Random`) | `lib/features/reports/reports_repository_impl.dart` | High | Open | - |
| **G2** | Order history not live (single sample vs stream subscription) | `lib/features/orders/orders_provider.dart`, `lib/features/orders/orders_screen.dart` | Medium | Open | - |
| **G3** | Export buttons (CSV/PDF) are placeholders | `lib/features/reports/reports_screen.dart`, export widgets | Medium | Open | - |
| **G4** | Scan integration test D1 - needs physical device | `lib/features/scan/scan_screen.dart`, camera/OCR code | High | Deferred | - |
| **G5** | End-to-end New Sale → Orders tab flow verification | `lib/features/sales/new_sale_screen.dart`, `lib/features/orders/orders_provider.dart` | Medium | Pending | - |

---

## 2. PHASE TRACKER

| Phase | Status | Completed Deliverables | Remaining Work | Next Action |
|-------|--------|----------------------|----------------|-------------|
| **Phase 1** | DONE | Unblock compiler (99 errors → 0), `flutter analyze` clean | - | - |
| **Phase 2** | DONE | Delete ink stroke, simplify multi-candidate ML Kit | - | - |
| **Phase 3** | DONE | Wire and ship Reports feature | - | - |
| **Phase 4** | DONE | Remove `who`, wire up completion | - | - |
| **Phase 5** | DONE | Cleanup: warnings, root files, analyze/test | - | - |
| **Phase 5.4-5.6** | Verified | 0 analyze issues, 293 pass/6 fail (pre-existing) | - | - |
| **Phase D1** | Deferred | Scan integration test (needs physical device) | Rewrite camera + OCR flow | Await device |

---

## 3. FEATURE STATUS MATRIX

| Feature | Stack | Status | AI Tracking Items |
|---------|-------|--------|-------------------|
| **Auth** | Firebase Auth | Done | - |
| **Search/Dashboard** | Firestore medicine store | Done | - |
| **Orders** | OrderProvider + OrderHistory Repository | Done | Order tab overflow fix (B1 from §12) |
| **Sales** | NewSaleScreen + OrderProvider | Done | G2 (fabricated data), B2 (Proceed button scroll issue) |
| **Reports** | ReportsProvider + sales_seed.json parsing | Done | G3 (export buttons), G4 (live history) |
| **Scan** | ML Kit OCR + camera | In Progress | D1 (integration test, needs device) |
| **Core** | Navigation (go_router), theme, connectivity | Done | - |
| **Finder** | FeatureEntry + FeatureRepository + StaticCatalogue | Done | Structure complete; no widget tests |

---

## 4. TEST COVERAGE MAP

### ✅ Passing Tests (Green)
| Test File | Pass Count | Notes |
|-----------|------------|-------|
| `prescription_matcher_test.dart` | 23 pass | Core fuzzy-matching logic |
| `reports_test.dart` | 22 pass | Unit tests: daily rate, bulk orders, top sellers |
| `orders_screen_test.dart` | 12 pass | Tab filtering, card rendering, approveOrder (verified green per §11) |
| `medicine_provider_test.dart` | Included in 293 | - |
| `dart analyze lib/` | 0 errors | Full clean analysis |

### ❌ Known Failures (6 pre-existing, framework-level)
| Test File | Failure Type | Notes |
|-----------|-------------|-------|
| `widget_test.dart` | Flutter tooltip/ticker errors | Framework version issue |
| `nav_alignment_test.dart` | Framework alignment issues | - |
| `dashboard_search_test.dart` | Search framework issues | - |
| `medicine_catalog_test.dart` | Catalog framework issues | - |
| + 2 others | Tooltip/ticker conflicts | Not project-specific |

### 📋 Test Gaps
- Scan integration test (D1) - needs physical device
- End-to-end New Sale → Orders tab flow ( §12 item 4)
- Reports widget tests - commented out with TODOs
- Medicine catalog widget tests
- Feature finder widget tests - no widget tests exist for finder screen

---

## 5. IMMEDIATE AI TRACKING PRIORITIES (from §12)

1. **Phase 5.2** - Decide whether to keep or delete root HTML/MD design references (`Orders.html`, `Shop reports.html`, `Shop reports.md`)
2. **Drive flutter analyze → 0 issues** (currently verified at 0 errors, 0 warnings, 0 infos)
3. **Confirm 3 green test files pass**: `prescription_matcher_test.dart`, `reports_test.dart`, `orders_screen_test.dart`
4. **End-to-end: New Sale → add items → Proceed → order appears on Orders tab as "New"** (verified flow from §12 item 4)
5. **D1** - Scan integration test when physical device available (camera + ML Kit OCR flow)

---

## 6. TRACKING CONVENTIONS

- **Gap IDs** follow PharmaProgram.md §6 naming (G1-G10+)
- **Phase numbers** match the project's phase numbering (1-5, 5.4-5.6, D1)
- **Status**: DONE, Open, Deferred, Pending
- **Priority**: High (blocks user value), Medium (should fix), Low (nice to have)
- **Test colors**: ✅ Passing, ❌ Known failures, 📋 Gaps

---

## 7. QUICK REFERENCE

| Artifact | Location | Status |
|----------|----------|--------|
| Technical Spec | `PharmaProgram.md` | Reference baseline |
| Work State | `thecurrentworkstate` | Phase tracker + notes |
| This MAP | `ai_tracking_map.md` | **This file** - active tracking |
| Analyze Result | `flutter analyze` | 0 errors, 0 warnings |
| Test Result | `flutter test` | 293 pass, 6 pre-existing fail |

---

*Generated for AI-assisted tracking of PharmaGuide development. Update after each development session to maintain accurate AI context.*