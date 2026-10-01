import 'package:flutter/foundation.dart';

/// Whether the catalogue can be heard from the server right now.
///
/// Three states rather than a bool, because "not heard from yet" and "heard from
/// and it is answering" are different answers and the offline banner has to give
/// one of them. [unknown] exists for the moment before the first snapshot: calling
/// that *online* would be a claim rather than a measurement, and a stale "online"
/// is exactly what hides a dead connection behind a cheerful green tick.
enum Reachability {
  /// Nothing has reported yet.
  unknown,

  /// The server answered.
  online,

  /// The last attempt did not get through.
  offline,
}

/// What the catalogue knows about its own freshness.
///
/// Every field is measured rather than counted on the SDK's behalf.
/// [pendingWriteCount] is a real number, but only because the app owns the queue
/// it comes from: it counts entries this device recorded and has not yet seen the
/// server confirm. Firestore itself reports *that* a snapshot holds uncommitted
/// writes and not how many, so a count taken from it would have to be invented by
/// subtracting confirmed writes from issued ones -- which is wrong the moment a
/// write is rejected at flush time or a second device edits the same line.
@immutable
class SyncStatus {
  const SyncStatus({
    this.reachability = Reachability.unknown,
    this.pendingWriteCount = 0,
    this.lastServerReadTime,
  });

  /// Nothing has been heard from the server yet.
  static const SyncStatus unknown = SyncStatus();

  /// A catalogue with no server behind it, such as a list held in the binary or
  /// in memory. There is nothing to sync and nothing that can be stale, so it
  /// reads as online rather than as a permanent unknown that would pin a banner
  /// on screen forever.
  static const SyncStatus localOnly = SyncStatus(
    reachability: Reachability.online,
  );

  final Reachability reachability;

  /// How many changes this device has taken and the server has not confirmed.
  ///
  /// Non-zero while offline with unsaved work, and also briefly while online: a
  /// write is recorded locally and confirmed when a snapshot that came off the
  /// wire arrives, which is a round trip later. It is therefore a reason to *not*
  /// claim everything is saved, never a reason to report a problem.
  ///
  /// Only ever a lower bound. A write handed to Firestore that it has already
  /// flushed on its own is confirmed by its next snapshot, and one the app has
  /// sent but not yet seen acknowledged is not counted -- see
  /// `FirestoreMedicineStore`, which is the only thing that fills this in.
  final int pendingWriteCount;

  /// When the data was last read off the server, or null if it never has been.
  ///
  /// The device's clock at the moment a non-cached snapshot arrived. Firestore's
  /// Dart client does not carry the server's read time, so there is no server
  /// clock to report -- which means a phone with a wrong date can make fresh data
  /// look hours old or new. That is a known limitation of being honest about the
  /// measurement rather than inventing one, and it only affects the "how old"
  /// figure, never whether anything is saved.
  final DateTime? lastServerReadTime;

  bool get isOffline => reachability == Reachability.offline;

  /// Whether there is anything waiting to be saved.
  bool get hasPendingChanges => pendingWriteCount > 0;

  /// Whether anything at all is known about the data's age.
  bool get isFresh => lastServerReadTime != null;

  /// How old the freshest data is, or null when nothing has been read.
  ///
  /// Takes the current time as an argument rather than reading the clock, so a
  /// test can pin it -- the same reason `MedicineModel.debugToday` exists.
  Duration? ageAt(DateTime now) {
    final read = lastServerReadTime;
    if (read == null) return null;
    final age = now.difference(read);
    // A server clock slightly ahead of the device is normal, not a negative age.
    return age.isNegative ? Duration.zero : age;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncStatus &&
          other.reachability == reachability &&
          other.pendingWriteCount == pendingWriteCount &&
          other.lastServerReadTime == lastServerReadTime;

  @override
  int get hashCode =>
      Object.hash(reachability, pendingWriteCount, lastServerReadTime);

  @override
  String toString() =>
      'SyncStatus(${reachability.name}'
      '${hasPendingChanges ? ', $pendingWriteCount pending' : ''}'
      '${lastServerReadTime == null ? '' : ', read $lastServerReadTime'})';
}