import 'send_warning_draft.dart' show sendWarningKnownAddress;

/// The original Home recipe runs with either tour coverage or catalog only.
bool isReadonlyHomeCatalogFamily(String? family) =>
    family == 'home' || family == 'home-catalog';

/// An isolated contact whose label is found by the authored Go To query.
const String homeGotoContactName = 'Delia';

/// Uses the synthetic address already exercised by the contact editor.
String get homeGotoContactKey => 'contact:$sendWarningKnownAddress';
