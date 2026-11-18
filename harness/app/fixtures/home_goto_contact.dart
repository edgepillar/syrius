import 'send_warning_draft.dart' show sendWarningKnownAddress;

/// An isolated contact whose label is found by the authored Go To query.
const String homeGotoContactName = 'Delia';

/// Uses the synthetic address already exercised by the contact editor.
String get homeGotoContactKey => 'contact:$sendWarningKnownAddress';
