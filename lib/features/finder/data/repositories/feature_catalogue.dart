import '../models/feature_entry.dart';
import 'feature_routes.dart';

/// Every screen the finder can find, transcribed by hand.
///
/// Hand-written rather than reflected or generated because a route table does
/// not carry the two things that make the finder useful: the words a user would
/// type, and a title that reads as a name rather than as a path segment. There
/// is no way to derive `expiry` from `/home/expiring` and no way to know that
/// `soon` and `outdated` both mean the same screen.
///
/// The declaration order below is grouped by section because that is the order
/// somebody adding an entry wants to read. It is *not* the order the finder
/// shows -- [FeatureEntry.compareByTitle] decides that, on every read. Editing
/// this list to change the on-screen order will not work, and is the one mistake
/// this file invites.
///
/// Titles mirror the screens' own AppBar titles where there is one, so a user
/// who reads "Expiring Meds" on the screen finds the same words here.
///
/// Admin-only routes are deliberately absent. The finder is only reachable from
/// the staff shell, and an admin never reaches that shell -- a Reports entry
/// here would offer a staff member a door the router's redirect would refuse.
const List<FeatureEntry> featureCatalogue = [
  // --- Home --------------------------------------------------------------
  FeatureEntry(
    id: 'home',
    title: 'Price List',
    subtitle: 'Search the catalogue by name or price',
    routePath: FeatureRoutes.home,
    aliases: ['search', 'medicines', 'catalog', 'catalogue', 'presyo', 'home'],
    parent: 'Home',
    iconKey: 'search',
  ),
  FeatureEntry(
    id: 'expiring',
    title: 'Expiring Meds',
    subtitle: 'Lapsed and soon-to-lapse lines, soonest first',
    routePath: FeatureRoutes.expiringMeds,
    aliases: ['expiry', 'expiration', 'expired', 'outdated', 'lapsed', 'soon'],
    parent: 'Home',
    iconKey: 'expiring',
  ),
  FeatureEntry(
    id: 'scan',
    title: 'Scan Prescription',
    subtitle: 'Read a prescription with the camera',
    routePath: FeatureRoutes.scan,
    aliases: ['ocr', 'camera', 'reseta', 'prescription', 'photo'],
    parent: 'Home',
    iconKey: 'scan',
  ),
  FeatureEntry(
    id: 'notifications',
    title: 'Notifications',
    subtitle: 'Alerts and low-stock notices',
    routePath: FeatureRoutes.notifications,
    aliases: ['alerts', 'attention', 'inbox', 'warnings'],
    parent: 'Home',
    iconKey: 'notifications',
  ),
  FeatureEntry(
    id: 'profile',
    title: 'Profile',
    subtitle: 'Signed-in user and sign out',
    routePath: FeatureRoutes.profile,
    aliases: ['account', 'sign out', 'logout', 'user', 'settings'],
    parent: 'Home',
    iconKey: 'profile',
  ),
  FeatureEntry(
    id: 'symptom-guide',
    title: 'Symptom Guide',
    subtitle: 'Match a symptom to a medicine and how to use it',
    routePath: FeatureRoutes.homeSymptomGuide,
    aliases: ['sakit', 'gamot', 'guide', 'illness', 'cold', 'cough', 'fever', 'headache'],
    parent: 'Home',
    iconKey: 'symptom',
  ),

  // --- Inventory ---------------------------------------------------------
  FeatureEntry(
    id: 'inventory',
    title: 'Inventory',
    subtitle: 'Count and correct stock on the shelf',
    routePath: FeatureRoutes.inventory,
    aliases: ['stock', 'count', 'quantities', 'imbentaryo'],
    parent: 'Inventory',
    iconKey: 'inventory',
  ),
  FeatureEntry(
    id: 'medicines',
    title: 'Medicine',
    subtitle: 'Browse and search the full medicine price list',
    routePath: FeatureRoutes.medicines,
    aliases: ['medicines', 'catalogue', 'catalog', 'products', 'price list'],
    parent: 'Medicine',
    iconKey: 'medicine',
  ),

  // --- Orders ------------------------------------------------------------
  FeatureEntry(
    id: 'orders',
    title: 'Orders',
    subtitle: 'Basket and past orders',
    routePath: FeatureRoutes.orders,
    aliases: ['basket', 'cart', 'history', 'order history'],
    parent: 'Orders',
    iconKey: 'orders',
  ),
  FeatureEntry(
    id: 'new_order',
    title: 'New Order',
    subtitle: 'Ring up a transaction',
    routePath: FeatureRoutes.newSale,
    aliases: ['sell', 'checkout', 'transaction', 'counter', 'pos'],
    parent: 'Orders',
    iconKey: 'sale',
  ),
];
