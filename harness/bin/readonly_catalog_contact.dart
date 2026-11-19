import '../app/fixtures/send_warning_draft.dart'
    show sendWarningKnownAddress, sendWarningTypedAddress;
import 'harness.dart' as cli;
import 'readonly_inspection_session.dart';

/// The original edit action for the isolated synthetic contact.
String get readonlyCatalogContactEditKey =>
    'addresses_edit_contact_$sendWarningKnownAddress';

/// The original edit action for the second synthetic Settings contact.
String get readonlyCatalogSecondContactEditKey =>
    'addresses_edit_contact_$sendWarningTypedAddress';

/// Enters the draft through the real field and requires its exact reply.
Future<void> typeReadonlyCatalogField(
  cli.Instance instance, String key, String value,
) async {
  final Map<String, dynamic> typed = await cli.call(instance, <String, Object?>{
    'cmd': 'type', 'key': key, 'exact': true, 'value': value,
  });
  if (typed['value'] != value) {
    throw const ReadonlyInspectionRefused(ReadonlyInspectionReason.reply);
  }
}

/// Saves the synthetic contact through the original isolated address book.
Future<void> prepareReadonlyCatalogContact(
  cli.Instance instance, {
  required String name,
}) async {
  await cli.goto(instance, 'settings');
  await cli.call(instance, <String, Object?>{
    'cmd': 'tap', 'key': 'settings_addresses', 'exact': true,
  });
  await saveReadonlyCatalogContact(instance, name: name);
  await cli.goto(instance, 'dashboard');
}

/// Saves one of the fixed synthetic contacts from the open Addresses page.
Future<void> saveReadonlyCatalogContact(
  cli.Instance instance, {
  required String name,
  bool second = false,
}) async {
  final String editKey = second
      ? readonlyCatalogSecondContactEditKey
      : readonlyCatalogContactEditKey;
  await cli.waitForTarget(instance, cli.Args(<String>[
    '--key', 'addresses_add_contact', '--kind', 'button',
    '--exact', '--ready', '--timeout', '20',
  ]));
  await cli.call(instance, <String, Object?>{
    'cmd': 'tap', 'key': 'addresses_add_contact', 'exact': true,
  });
  await cli.call(instance, <String, Object?>{'cmd': 'scroll', 'dy': 440});
  await cli.waitForTarget(instance, cli.Args(<String>[
    '--key', 'addresses_contact_name', '--kind', 'field',
    '--exact', '--ready', '--timeout', '10',
  ]));
  await typeReadonlyCatalogField(instance, 'addresses_contact_name', name);
  await typeReadonlyCatalogField(
    instance,
    'addresses_contact_address',
    second ? sendWarningTypedAddress : sendWarningKnownAddress,
  );
  await cli.call(instance, <String, Object?>{
    'cmd': 'tap', 'key': 'addresses_save_contact', 'exact': true,
  });
  await cli.waitForTarget(instance, cli.Args(<String>[
    '--key', editKey,
    '--kind', 'button',
    '--exact', '--ready', '--timeout', '10',
  ]));
}
