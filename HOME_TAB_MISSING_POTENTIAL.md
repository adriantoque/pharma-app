# Home Tab - Missing Potential & Enhancement Opportunities

## Current State Summary
The Home tab (`DashboardScreen`) is a navigation hub with 3 tiles pushing child pages:
- Real Time Inventory → `InventoryScreen`
- Sales & Reports → `ReportsScreen`
- Expiring Meds → `ExpiringMedsScreen`

---

## 1. Dashboard Screen (`DashboardScreen`)

### Missing Features
- [ ] **Live metrics on tiles** — Currently tiles show only icon/title/subtitle (code comment: "Shows no figure yet: there is no data layer, so a number here would be invented")
  - Inventory tile: "X of Y counted" + total value
  - Reports tile: "This month: ₱X revenue, Y units/day"
  - Expiring tile: "N expired, M expiring ≤30 days"
- [ ] **Pull-to-refresh** on dashboard to reload all three summaries
- [ ] **Quick actions** — FAB or header actions (e.g., "Start Stock Take", "Record Expiry")
- [ ] **Role-based visibility** — Hide Reports/Expiring for non-manager roles

### Technical Debt
- `DashboardTile` widget explicitly documents "no data layer" — needs `MedicineProvider` + `SalesRepository` integration
- No loading/error states on tile level

---

## 2. Real Time Inventory (`InventoryScreen`)

### Missing Features
- [ ] **Bulk count entry** — Current UX: one-by-one via bottom sheet. Need:
  - Multi-select mode (checkboxes) → batch "Set counted to 0" or "Apply count"
  - CSV/Excel import for stock take sheets
  - Barcode/QR scan to jump to product
- [ ] **Count sessions/history** — Track who counted what, when (audit trail)
- [ ] **Variance highlighting** — Compare current count vs previous count vs expected (from sales)
- [ ] **Location/bin tracking** — Shelf/bin location per product
- [ ] **Low stock alerts** — Configurable threshold per product, push notification
- [ ] **Export counted list** — CSV/PDF for physical records
- [ ] **Offline-first sync indicator** — Show pending writes to Firestore

### UX Improvements
- [ ] **Swipe actions** on list rows (quick count, edit, view history)
- [ ] **Keyboard shortcuts** (desktop/web): Enter to save, Esc to cancel
- [ ] **Voice input** for hands-free counting

---

## 3. Sales & Reports (`ReportsScreen`)

### Missing Features
- [ ] **Export capabilities**
  - CSV export (filtered by month/kind)
  - PDF report with charts
  - Email/share integration
- [ ] **Date range picker** — Custom range (not just month chips)
- [ ] **Year-over-year comparison** — Same month last year vs this year
- [ ] **Charts/visualizations**
  - Revenue trend line (daily/weekly/monthly)
  - Top products bar chart
  - Counter vs Bulk split pie chart
- [ ] **Profit margin analysis** — Needs cost data (not just sale price)
- [ ] **Reorder suggestions** — Based on velocity + lead time
- [ ] **Customer analysis** — Bulk customer frequency, value, last order
- [ ] **Category/department breakdown** — If medicines have categories
- [ ] **Daily/weekly summary cards** — "Today so far", "This week vs last week"
- [ ] **Print-friendly layout** — For physical filing

### Data Enhancements
- [ ] **Real-time sales recording** — Currently reads static seed only
- [ ] **POS integration** — API/webhook for live sales feed
- [ ] **Returns/refunds tracking** — Negative sales lines

---

## 4. Expiring Meds (`ExpiringMedsScreen`)

### Missing Features
- [ ] **Push/local notifications**
  - "X items expiring in 7 days"
  - Daily/weekly digest
  - Configurable lead times (30/60/90 days)
- [ ] **Batch expiry entry** — Scan multiple products, set same expiry date
- [ ] **Expiry history** — When was date set/changed, by whom
- [ ] **Auto-clear expired** — Option to auto-set stock=0 when expired
- [ ] **FEFO/FIFO picking list** — "Pick oldest expiry first" for orders
- [ ] **Supplier/lot tracking** — Link expiry to purchase order / supplier
- [ ] **Export expiring list** — CSV for procurement team
- [ ] **Visual timeline** — Calendar heatmap of expiries

### UX Improvements
- [ ] **Swipe to set expiry** from Inventory screen (don't need separate tab)
- [ ] **Color-coded list rows** by urgency (already partially done via subtitle)
- [ ] **Search within expiring list**

---

## 5. Cross-Cutting / Platform

### Architecture
- [ ] **Unified "Stock Take" workflow** — Combine Inventory + Expiry into guided session
- [ ] **Background sync** — Firestore listeners already work; add sync status banner
- [ ] **Conflict resolution** — Multi-device count edits (last-write-wins vs merge)
- [ ] **Analytics/telemetry** — Track feature usage (privacy-respecting)

### Testing
- [ ] **Integration tests** for all three child screens
- [ ] **Golden tests** for report layouts
- [ ] **Load testing** with 1000+ products

### Accessibility
- [ ] **Screen reader labels** on all custom widgets
- [ ] **High contrast mode** verification
- [ ] **Dynamic type** scaling tested

---

## Priority Matrix

| Enhancement | Impact | Effort | Priority |
|-------------|--------|--------|----------|
| Live metrics on dashboard tiles | High | Medium | **P1** |
| Bulk count entry (Inventory) | High | High | **P1** |
| CSV export (Reports) | High | Medium | **P1** |
| Push notifications (Expiring) | High | High | **P1** |
| Count history/audit | Medium | High | P2 |
| Charts/visualizations (Reports) | Medium | High | P2 |
| Barcode scan to product | Medium | Medium | P2 |
| Year-over-year comparison | Medium | Medium | P2 |
| FEFO picking list | Medium | Medium | P3 |
| Voice input | Low | High | P3 |
| Role-based visibility | Medium | Low | P2 |

---

## Implementation Notes

### For Dashboard Tile Metrics (P1)
```dart
// In DashboardScreen.build():
final catalogue = context.watch<MedicineProvider>();
final counted = catalogue.all().where((m) => m.stock != null).length;
final total = catalogue.all().length;
final value = catalogue.all()
    .where((m) => m.stock != null)
    .fold<int>(0, (sum, m) => sum + m.priceCentavos * m.stock!);

// Pass to DashboardTile as trailing/subtitle
DashboardTile(
  ...
  subtitle: '$counted of $total counted · ${formatCentavos(value)}',
)
```

### For Bulk Count Entry
- Add `SelectionMode` to `InventoryScreen` (toggle via AppBar action)
- Use `ListView.separated` with `CheckboxListTile` or custom selectable row
- Bottom sheet with "Apply count to selected" + number field

### For Reports Export
```dart
// Add to ReportsScreen AppBar actions:
IconButton(
  icon: Icon(Icons.download),
  onPressed: () => _exportCSV(repository, _month),
)
```

### For Expiry Notifications
- Use `flutter_local_notifications` + `workmanager`/`android_alarm_manager`
- Schedule daily check at 9 AM
- Query `MedicineProvider` for expiring items
- Show notification with count + deep link to ExpiringMedsScreen

---

## Related Files to Modify

| Feature | Files |
|---------|-------|
| Dashboard metrics | `lib/features/dashboard/presentation/screens/dashboard_screen.dart`, `lib/features/dashboard/presentation/widgets/dashboard_tile.dart` |
| Bulk inventory | `lib/features/dashboard/presentation/screens/inventory_screen.dart`, new `bulk_stock_sheet.dart` |
| Reports export | `lib/features/dashboard/presentation/screens/reports_screen.dart`, new `export_service.dart` |
| Expiry notifications | `lib/features/dashboard/presentation/screens/expiring_meds_screen.dart`, new `notification_service.dart`, `pubspec.yaml` |

---

*Generated: 2026-10-01*
*Based on codebase analysis of PharmaGuide Home tab*