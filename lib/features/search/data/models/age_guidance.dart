/// Who a medicine is meant for.
///
/// [both] is the default, because the price list says nothing about age for
/// most lines and "not recorded" must not be read as "for adults only": a
/// shelf item that is safe for either age group has to stay visible to both
/// filters.
enum AgeGroup {
  /// Made for children: the dose, the form and the strength are all chosen
  /// for a smaller body.
  child,

  /// Made for adults.
  adult,

  /// Not recorded, or made for either.
  both,
}

/// One age group's rating from the pharmacy inventory sheet.
enum AgeSuitability {
  /// Generally suitable when used as labelled.
  yes,

  /// Only with advice from a doctor or pharmacist: a dose limit, an age limit
  /// or a higher risk of side effects.
  caution,

  /// Not recommended for this group; a different form or a doctor's advice is
  /// needed.
  no,
}

/// The four age ratings recorded for one product.
///
/// Stored as a value object rather than four nullable booleans so a partly
/// filled row cannot be half-read: [tryParse] returns null unless all four
/// ratings are present and valid. That keeps "not recorded" apart from
/// "suitable", which matters because the child filter offers a line on a
/// [AgeSuitability.yes] *or* [AgeSuitability.caution] rating.
class AgeGuidance {
  const AgeGuidance({
    this.kids = AgeSuitability.yes,
    this.teens = AgeSuitability.yes,
    this.adults = AgeSuitability.yes,
    this.seniors = AgeSuitability.yes,
  });

  /// The ratings a legacy line with only an [AgeGroup] would have had.
  ///
  /// Used when a document predates the per-age columns, so the older two-value
  /// filter keeps behaving exactly as it did.
  factory AgeGuidance.fromGroup(AgeGroup group) => switch (group) {
    AgeGroup.child => const AgeGuidance(
      kids: AgeSuitability.yes,
      teens: AgeSuitability.no,
      adults: AgeSuitability.no,
      seniors: AgeSuitability.no,
    ),
    AgeGroup.adult => const AgeGuidance(
      kids: AgeSuitability.no,
    ),
    AgeGroup.both => const AgeGuidance(),
  };

  final AgeSuitability kids;
  final AgeSuitability teens;
  final AgeSuitability adults;
  final AgeSuitability seniors;

  /// Reads a `{kids, teens, adults, seniors}` map, or null when it is missing
  /// or any value is not one of `yes`, `caution`, `no`.
  ///
  /// Null rather than a default because a line whose ratings could not be read
  /// must fall back to its recorded [AgeGroup], not be declared suitable for
  /// every age group.
  static AgeGuidance? tryParse(Object? value) {
    if (value is! Map) return null;
    final kids = _read(value['kids']);
    final teens = _read(value['teens']);
    final adults = _read(value['adults']);
    final seniors = _read(value['seniors']);
    if (kids == null || teens == null || adults == null || seniors == null) {
      return null;
    }
    return AgeGuidance(
      kids: kids,
      teens: teens,
      adults: adults,
      seniors: seniors,
    );
  }

  static AgeSuitability? _read(Object? value) {
    final name = value?.toString().toLowerCase().trim();
    for (final rating in AgeSuitability.values) {
      if (rating.name == name) return rating;
    }
    return null;
  }

  /// Whether this line belongs on the list for [group].
  ///
  /// A [AgeSuitability.caution] rating counts as offered: the counter should
  /// see the line together with the warning, rather than have it disappear and
  /// be sold without the warning.
  bool isForGroup(AgeGroup group) => switch (group) {
    AgeGroup.both => true,
    AgeGroup.child => kids != AgeSuitability.no,
    // The app's "adult" filter means everyone past childhood, so any of the
    // three older groups being allowed is enough.
    AgeGroup.adult =>
      teens != AgeSuitability.no ||
          adults != AgeSuitability.no ||
          seniors != AgeSuitability.no,
  };

  /// `Kids (caution), Teens, Adults, Seniors`, the workbook's Suitable For
  /// column rebuilt from the four ratings.
  String get label {
    final parts = <String>[
      if (kids != AgeSuitability.no) _label('Kids', kids),
      if (teens != AgeSuitability.no) _label('Teens', teens),
      if (adults != AgeSuitability.no) _label('Adults', adults),
      if (seniors != AgeSuitability.no) _label('Seniors', seniors),
    ];
    return parts.isEmpty ? 'Not recorded' : parts.join(', ');
  }

  static String _label(String name, AgeSuitability rating) =>
      rating == AgeSuitability.caution ? '$name (caution)' : name;

  /// Whether any group is rated [AgeSuitability.caution], so a caller can show
  /// one warning without walking the four fields itself.
  bool get hasCaution =>
      kids == AgeSuitability.caution ||
      teens == AgeSuitability.caution ||
      adults == AgeSuitability.caution ||
      seniors == AgeSuitability.caution;

  Map<String, String> toMap() => {
    'kids': kids.name,
    'teens': teens.name,
    'adults': adults.name,
    'seniors': seniors.name,
  };
}
