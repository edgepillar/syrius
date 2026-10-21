import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/features/home/home.dart'
    show splitAmount;
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/page/page_widgets.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_colors.dart';
import 'package:zenon_syrius_wallet_flutter/utils/app_theme.dart';
import 'package:zenon_syrius_wallet_flutter/utils/navigation_utils.dart';
import 'package:zenon_syrius_wallet_flutter/utils/zts_utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/modular_widgets/accelerator_widgets/accelerator_parts.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/accelerator_project_details.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// The head of a project's page: what it is, who owns it, and how much of
/// its budget has been paid, as a meter per coin.
///
/// Replaces two pie charts with three legends each: paid, remaining and
/// total are one line and one meter.
class ProjectsStats extends StatelessWidget {
  /// Creates the head of [project].
  const ProjectsStats(this.project, {super.key});

  /// The project shown.
  final Project project;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle dim = theme.textTheme.titleMedium!.copyWith(fontSize: 13);
    return Panel(
      padding: const EdgeInsets.fromLTRB(20, 16, 24, 16),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                AccStatusChip(project.status),
                const SizedBox(height: 10),
                AcceleratorProjectDetails(
                  owner: project.owner,
                  hash: project.id,
                  creationTimestamp: project.creationTimestamp,
                  acceleratorProjectStatus: project.status,
                ),
                const SizedBox(height: 8),
                Tooltip(
                  message: project.description,
                  waitDuration: const Duration(milliseconds: 600),
                  child: Text(
                    project.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: dim.copyWith(height: 1.4),
                  ),
                ),
                if (project.url.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  InkWell(
                    mouseCursor: SystemMouseCursors.click,
                    onTap: () =>
                        unawaited(NavigationUtils.openUrl(project.url)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            project.url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: monoStyle(
                              dim.copyWith(
                                fontSize: 12,
                                color: AppColors.znnColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.open_in_new,
                          size: 13,
                          color: AppColors.znnColor,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            flex: 2,
            child: _Funding(
              label: 'ZNN paid',
              paid: project.getPaidZnnFunds(),
              total: project.getTotalZnnFunds(),
              symbol: kZnnCoin.symbol,
              color: AppColors.znnColor,
            ),
          ),
          const SizedBox(width: 28),
          Expanded(
            flex: 2,
            child: _Funding(
              label: 'QSR paid',
              paid: project.getPaidQsrFunds(),
              total: project.getTotalQsrFunds(),
              symbol: kQsrCoin.symbol,
              color: AppColors.qsrColor,
            ),
          ),
          const SizedBox(width: 28),
          Figure(
            label: 'Phases',
            value: '${project.phases.length}',
          ),
        ],
      ),
    );
  }
}

/// Paid of total for one coin, over a meter.
class _Funding extends StatelessWidget {
  const _Funding({
    required this.label,
    required this.paid,
    required this.total,
    required this.symbol,
    required this.color,
  });

  final String label;
  final BigInt paid;
  final BigInt total;
  final String symbol;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle value = monoStyle(
      theme.textTheme.bodyLarge,
    ).copyWith(fontSize: 18, fontWeight: FontWeight.w500);
    final TextStyle faint = monoStyle(
      theme.textTheme.bodyLarge,
    ).copyWith(fontSize: 13, color: AppColors.faint);
    final double share = total == BigInt.zero ? 0 : paid / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(label.toUpperCase(), style: ledgerLabelStyle(context)),
        const SizedBox(height: 4),
        Text.rich(
          TextSpan(
            children: <InlineSpan>[
              TextSpan(
                text: splitAmount(paid, coinDecimals).$1,
                style: value,
              ),
              TextSpan(
                text: ' of ${splitAmount(total, coinDecimals).$1} $symbol',
                style: faint,
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.fade,
          softWrap: false,
        ),
        const SizedBox(height: 8),
        AccMeter(parts: <(double, Color)>[(share, color)]),
      ],
    );
  }
}
