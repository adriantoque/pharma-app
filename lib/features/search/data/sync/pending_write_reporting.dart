/// A price list store whose writes it has not yet seen confirmed can be named.
///
/// [SyncedMedicineStore] mirrors the server's answer into the local database,
/// and a mirror must not overwrite an edit this device made and the server has
/// not confirmed yet -- the write is the newer fact, held in the pending queue
/// until a snapshot that came off the wire acknowledges it. So the mirror asks
/// which documents are still waiting, and leaves those rows alone.
///
/// An interface rather than a field on [MedicineStore] because a store with no
/// queue -- a static list, a test fake -- has nothing to report and should not
/// have to invent an answer. The mirror checks `case` against this and skips
/// the question for anything that cannot answer it.
abstract interface class PendingWriteReporting {
  /// Document ids with a write this device recorded and the server has not
  /// acknowledged.
  Set<String> get pendingDocumentIds;
}
