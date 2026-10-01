import 'sync_status.dart';

/// Re-exported rather than declared here: the search feature's store needs it,
/// but it is a lifecycle contract shared with the orders tab, and a second
/// interface with the same name would be two ways to ask the same question.
export '../../../../core/lifecycle/disposable_store.dart';

/// A store that can say how it relates to a server.
///
/// Separate from [MedicineStore] rather than folded into it, for two reasons.
/// A store with no server -- the bundled catalogue, a list built in a test --
/// has nothing to report and should not have to invent an answer. And a
/// decorator like the offline store can forward the inner store's status
/// unchanged, instead of reimplementing the bookkeeping on the way past.
abstract interface class SyncStatusSource {
  /// How the data relates to its server, changing as that relationship does.
  ///
  /// Emits the current status to every new subscriber before the live updates,
  /// so a listener always has something to paint and never waits on a first
  /// event that may not arrive while offline.
  Stream<SyncStatus> watchSyncStatus();
}