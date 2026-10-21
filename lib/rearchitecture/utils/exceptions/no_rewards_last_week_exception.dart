import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:zenon_syrius_wallet_flutter/l10n/l10n.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/exceptions/exceptions.dart';

part 'no_rewards_last_week_exception.g.dart';

/// A [SyriusException] used when there are no pillar rewards in the last week.
@immutable
@JsonSerializable()
class NoRewardsLastWeekException extends SyriusException {
  /// Creates a [NoRewardsLastWeekException] instance
  ///
  /// With no [message] it says "No rewards in the last week" in the language
  /// the app is showing when it is made.
  NoRewardsLastWeekException({
    String? message,
  }) : super(message ?? currentL10n.rewardsHistoryLastWeekEmpty);

  /// {@macro instance_from_json}
  factory NoRewardsLastWeekException.fromJson(
    Map<String, dynamic> json,
  ) => _$NoRewardsLastWeekExceptionFromJson(json);

  @override
  Map<String, dynamic> toJson() =>
      _$NoRewardsLastWeekExceptionToJson(this)
        ..['runtimeType'] = 'NoRewardsLastWeekException';

  @override
  bool operator ==(Object other) {
    return other is NoRewardsLastWeekException &&
        other.runtimeType == runtimeType &&
        other.message == message;
  }

  @override
  int get hashCode => message.hashCode;
}
