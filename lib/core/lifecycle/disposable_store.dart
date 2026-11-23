/// Something holding resources that have to be handed back.
///
/// Not part of any store interface, because a store's callers cannot be made to
/// release it and most stores have nothing to release. A store that wraps another
/// store, though, holds a subscription to it -- and stores are created per
/// signed-in account on a shared counter tablet, so without this each session
/// would leave a controller and its listener behind.
///
/// In `core` rather than beside the search feature's own interfaces, because the
/// orders tab wraps a store the same way and reaching into another feature for a
/// lifecycle interface is how a package boundary stops meaning anything.
abstract interface class DisposableStore {
  /// Releases whatever the store is holding. Must tolerate being called twice.
  void dispose();
}