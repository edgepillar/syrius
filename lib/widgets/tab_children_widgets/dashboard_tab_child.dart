import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/features.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';

/// The Home tab. Since the refresh it is the balance-first home of mockup B
/// ([HomeView]); the grid of network statistics cards it used to hold is gone
/// from here, and those figures belong to the pages they describe.
class DashboardTabChild extends StatelessWidget {
  const DashboardTabChild({super.key, this.changePage});

  final void Function(Tabs)? changePage;

  @override
  Widget build(BuildContext context) {
    return HomeView(changePage: changePage ?? (_) {});
  }
}
