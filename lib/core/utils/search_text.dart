/// Text handling shared by anything that matches a typed query against a
/// stored name.
///
/// Extracted so the medicine search and the feature finder fold text the same
/// way. Two copies of [normaliseForSearch] would agree today and drift the
/// first time one of them learns about a new punctuation mark, and the symptom
/// -- `Baby-Oil` matching in one screen and not the other -- is the kind of
/// thing that takes an afternoon to find.
library;

/// Lowercases [value] and drops everything that is not a letter or a digit.
///
/// So `Expiring Meds` and `expiring-meds` both become `expiringmeds`, and a
/// user who types either spelling finds the same row. Applied to both the query
/// and the candidate, which is what makes the comparison case- and
/// punctuation-insensitive without either side having to know the other's shape.
String normaliseForSearch(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
