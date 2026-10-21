import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/create_token_stepper/widgets/token_step_parts.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/modals/modal_chrome.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// Plasma check step for the pillar creation flow.
class PillarPlasmaCheckStep extends StatelessWidget {
  /// Creates a [PillarPlasmaCheckStep].
  const PillarPlasmaCheckStep({
    required this.addressController,
    required this.onNextPressed,
    this.active = true,
    super.key,
  });

  /// Selected address controller displayed by the disabled address field.
  final TextEditingController addressController;

  /// Called when the user can continue to the next step.
  final VoidCallback onNextPressed;

  /// Whether this is the step shown.
  final bool active;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PlasmaInfo?>(
      future: zenon!.embedded.plasma.get(Address.parse(kSelectedAddress!)),
      builder: (_, AsyncSnapshot<PlasmaInfo?> snapshot) {
        if (snapshot.hasError) {
          return SyriusErrorWidget(snapshot.error!);
        } else if (snapshot.hasData) {
          return _Body(
            active: active,
            addressController: addressController,
            onNextPressed: onNextPressed,
            plasmaInfo: snapshot.data!,
          );
        }
        return const SyriusLoadingWidget();
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.active,
    required this.addressController,
    required this.onNextPressed,
    required this.plasmaInfo,
  });

  final bool active;
  final TextEditingController addressController;
  final VoidCallback onNextPressed;
  final PlasmaInfo plasmaInfo;

  @override
  Widget build(BuildContext context) {
    final AppTokens tokens = AppTokens.of(context);
    final bool enough = plasmaInfo.currentPlasma >= kPillarPlasmaAmountNeeded;
    return TokenStepFrame(
      active: active,
      onSubmit: enough ? onNextPressed : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AccField(
            label: context.l10n.address,
            child: Row(
              children: <Widget>[
                Expanded(child: DisabledAddressField(addressController)),
                SizedBox(width: tokens.cardGap),
                PlasmaIcon(plasmaInfo),
              ],
            ),
          ),
          SizedBox(height: tokens.cardGap),
          // Under the field it is about. It is the reason Next is disabled
          // when there is too little Plasma, and then it takes the warning
          // tone.
          Text(
            context.l10n.morePlasmaRequired,
            style: kBodyMediumTextStyle.copyWith(
              fontFamily: kSansFontFamily,
              height: 1.4,
              color: enough ? dimColorOf(context) : tokens.warn,
            ),
          ),
        ],
      ),
      // The key stays on a wrapper: the button is looked up under it.
      primary: KeyedSubtree(
        key: const Key('pillar_plasma_next_button'),
        child: OutlinedButton(
          onPressed: enough ? onNextPressed : null,
          child: Text(context.l10n.next),
        ),
      ),
    );
  }
}
