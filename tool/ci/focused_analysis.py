"""One ordered strict Dart analysis selection for Linux and Windows CI."""

import json
from pathlib import Path
import re
import subprocess
import sys

SELECTED_DART_SOURCES = (
    'tool/ci/windows_debug_service_probe.dart',
    'harness/app/main.dart',
    'harness/app/native_launch_capture.dart',
    'harness/app/native_lock_catalog.dart',
    'harness/app/native_quiz_catalog.dart',
    'harness/app/fixtures/seed_quiz_fixture.dart',
    'harness/app/presentation_host.dart',
    'harness/app/fixtures/launch_settle_profile.dart',
    'lib/widgets/tab_children_widgets/lock_wallet_picker.dart',
    'harness/bin/harness.dart',
    'test/harness/wallet_tour_test.dart',
    'harness/app/theme_control.dart',
    'test/harness/theme_control_test.dart',
    'harness/bin/copied_wallet_pointer.dart',
    'test/harness/copied_wallet_pointer_test.dart',
    'harness/bin/ci_copied_wallet_pointer.dart',
    'test/harness/copied_pointer_input_test.dart',
    'harness/bin/ci_wallet_reopen.dart',
    'test/harness/restored_startup_test.dart',
    'test/harness/restored_unlock_ready_test.dart',
    'test/harness/lock_view_observation_test.dart',
    'test/harness/import_selector_metrics_test.dart',
    'test/import_redesign/import_surface_test.dart',
    'harness/lock_view_observation.dart',
    'harness/home_preparation_observation.dart',
    'lib/widgets/tab_children_widgets/lock_tab_child.dart',
    'test/onboarding/welcome_drop_route_test.dart',
    'test/welcome/welcome_surface_test.dart',
    'lib/screens/onboarding/welcome_surface.dart',
    'test/welcome/support.dart',
    'harness/seed/restored_seed_workflow.dart',
    'test/harness/restored_seed_workflow_test.dart',
    'harness/app/fixtures/lab_quiescence.dart',
    'test/harness/lab_quiescence_test.dart',
    'harness/bin/build_output.dart',
    'test/harness/build_output_test.dart',
    'harness/bin/ci_wallet_tour.dart',
    'harness/bin/wallet_recipe.dart',
    'harness/wallet_address_context.dart',
    'test/harness/wallet_address_recipe_test.dart',
    'test/harness/addresses_selection_test.dart',
    'harness/app/fixtures/lab_transfer_witness.dart',
    'test/harness/lab_transfer_witness_test.dart',
    'harness/seed/seed_recipe.dart',
    'test/harness/seed_recipe_test.dart',
    'harness/app/fixtures/seed_policy.dart',
    'harness/app/fixtures/seed_stake_effect.dart',
    'harness/app/fixtures/seed_commands.dart',
    'harness/app/fixtures/seeded_surface_seam.dart',
    'harness/app/seeded_surface_seam_binding.dart',
    'test/harness/seeded_surface_seam_test.dart',
    'harness/seed_preparation_failure.dart',
    'harness/app/fixtures/seed_project_presentation.dart',
    'harness/app/seed_project_presentation_binding.dart',
    'harness/app/fixtures/seed_token_presentation.dart',
    'harness/app/fixtures/seed_deposit_entry.dart',
    'harness/app/seed_deposit_entry_binding.dart',
    'test/harness/seed_deposit_entry_test.dart',
    'harness/app/fixtures/seed_deposit_presentation.dart',
    'harness/app/seed_deposit_presentation_binding.dart',
    'test/harness/seed_deposit_presentation_test.dart',
    'test/harness/seed_fixture_admission_test.dart',
    'harness/app/seed_token_presentation_binding.dart',
    'lib/rearchitecture/features/registration_success/registration_confirmation.dart',
    'test/harness/seed_policy_test.dart',
    'lib/widgets/modular_widgets/accelerator_widgets/accelerator_action_stepper.dart',
    'harness/app/fixtures/lab_seed_binding.dart',
    'harness/app/fixtures/lab_send_policy.dart',
    'harness/app/fixtures/lab_send_ui_binding.dart',
    'test/harness/lab_send_ui_binding_test.dart',
    'harness/lab_send_failure.dart',
    'test/harness/lab_send_failure_test.dart',
    'test/harness/lab_sender_menu_test.dart',
    'test/harness/transfer_sender_header_test.dart',
    'lib/rearchitecture/features/send/widgets/send_populated.dart',
    'test/send/widgets/send_form_test.dart',
    'lib/rearchitecture/features/create_stake/view/create_stake_card.dart',
    'test/staking/view/create_stake_card_test.dart',
    'lib/rearchitecture/features/cancel_stake/bloc/cancel_stake_bloc.dart',
    'lib/rearchitecture/features/cancel_stake/view/cancel_stake_button.dart',
    'lib/rearchitecture/features/stakes/view/stakes_card.dart',
    'test/cancel_stake/bloc/cancel_stake_bloc_test.dart',
    'test/cancel_stake/view/cancel_stake_button_test.dart',
    'test/staking/view/stakes_card_test.dart',
    'lib/widgets/tab_children_widgets/staking_tab_child.dart',
    'test/staking/view/staking_page_test.dart',
    'lib/widgets/tab_children_widgets/nodes_tab_child.dart',
    'lib/rearchitecture/features/delegation_stats/view/delegation_strip.dart',
    'harness/app/fixtures/sentinel_fixture.dart',
    'lib/rearchitecture/features/sentinels/view/sentinels_card.dart',
    'lib/rearchitecture/features/sentinels/view/sentinel_values.dart',
    'lib/rearchitecture/features/sentinels_by_owner/view/sentinel_strip.dart',
    'test/sentinels/view/sentinels_card_test.dart',
    'test/sentinels/view/sentinel_values_test.dart',
    'test/sentinels_by_owner/view/sentinel_strip_test.dart',
    'test/shell/rail_test.dart',
    'lib/rearchitecture/features/node_owner/node_collect_button.dart',
    'test/nodes/nodes_rewards_test.dart',
    'lib/widgets/modular_widgets/accelerator_widgets/accelerator_list_view.dart',
    'lib/widgets/modular_widgets/accelerator_widgets/accelerator_stats.dart',
    'test/accelerator_list_redesign/accelerator_list_view_test.dart',
    'lib/widgets/shell/bell_panel.dart',
    'test/shell/bell/bell_panel_test.dart',
    'test/helpers/mockup_symbol.dart',
    'lib/rearchitecture/features/fused_plasma/view/fused_plasma_card.dart',
    'lib/widgets/tab_children_widgets/plasma_tab_child.dart',
    'test/plasma_redesign/plasma_list_test.dart',
    'lib/rearchitecture/features/plasma_stats/view/plasma_stats_card.dart',
    'test/plasma_redesign/plasma_stats_layout_test.dart',
    'test/shaders/entry_field_test.dart',
    'test/rearchitecture/utils/widgets/plasma_well_test.dart',
    'lib/widgets/modular_widgets/p2p_swap_widgets/p2p_swaps_card.dart',
    'lib/widgets/modular_widgets/p2p_swap_widgets/p2p_swap_options_card.dart',
    'test/swap_list_redesign/swap_list_view_test.dart',
    'lib/rearchitecture/utils/widgets/segment.dart',
    'lib/rearchitecture/utils/widgets/page/page_widgets.dart',
    'lib/widgets/modular_widgets/settings_widgets/node_settings_view.dart',
    'lib/widgets/modular_widgets/settings_widgets/security_settings_rows.dart',
    'lib/widgets/modular_widgets/settings_widgets/settings_parts.dart',
    'test/segment/segment_test.dart',
    'test/segment/segment_availability_test.dart',
    'test/segment/segment_heading_test.dart',
    'test/rearchitecture/utils/widgets/panel_test.dart',
    'test/page/panel_collapse_test.dart',
    'test/settings_node_redesign/node_settings_view_test.dart',
    'lib/rearchitecture/features/send/bloc/send_transaction/send_transaction_bloc.dart',
    'test/send/bloc/sender_admission_test.dart',
    'test/harness/lab_send_policy_test.dart',
    'test/harness/lab_send_journal_test.dart',
    'test/harness/selection_context_revision_test.dart',
    'lib/utils/notifiers/default_address_notifier.dart',
    'lib/widgets/main_app_container.dart',
    'lib/utils/app_theme.dart',
    'test/theme/mockup_tokens_test.dart',
    'lib/widgets/shell/rail.dart',
    'lib/rearchitecture/features/latest_transactions/view/activity_row.dart',
    'test/latest_transactions/activity_row_test.dart',
    'lib/rearchitecture/features/pillars/view/pillars_card.dart',
    'test/pillars/view/pillars_card_test.dart',
    'lib/rearchitecture/utils/widgets/disclosure.dart',
    'lib/rearchitecture/utils/widgets/row_detail.dart',
    'test/disclosure/disclosure_test.dart',
    'test/row_detail/row_detail_test.dart',
    'lib/widgets/shell/shell_frame.dart',
    'lib/rearchitecture/features/transfer/view/transfer_page.dart',
    'lib/rearchitecture/features/zap.dart',
    'lib/rearchitecture/features/zap/view/zap_form.dart',
    'lib/rearchitecture/features/zap/view/zap_received_message.dart',
    'lib/utils/balances.dart',
    'lib/widgets/modals.dart',
    'lib/rearchitecture/utils/widgets/widgets.dart',
    'test/zap/zap_form_test.dart',
    'test/zap/zap_received_message_test.dart',
    'lib/rearchitecture/utils/widgets/buttons/paste_content_button.dart',
    'lib/rearchitecture/utils/widgets/buttons/clear_content_button.dart',
    'test/rearchitecture/utils/widgets/field_suffix_buttons_test.dart',
    'lib/rearchitecture/features/receive/receive_header_controller.dart',
    'lib/rearchitecture/features/receive/view/receive_card.dart',
    'lib/rearchitecture/features/receive/widgets/receive_populated.dart',
    'test/receive/receive_populated_test.dart',
    'test/shell/shell_frame_test.dart',
    'test/shell/go_to_catalog_test.dart',
    'test/shell/shortcuts_test.dart',
    'lib/widgets/shell/go_to_catalog.dart',
    'lib/widgets/shell/shortcuts.dart',
    'test/transfer/view/transfer_page_test.dart',
    'lib/rearchitecture/features/home/view/home_hero.dart',
    'lib/rearchitecture/utils/widgets/hero_field.dart',
    'lib/rearchitecture/features/home/view/home_view.dart',
    'lib/rearchitecture/utils/widgets/eye_toggle.dart',
    'test/home/home_hero_test.dart',
    'test/go_to_palette/go_to_palette_test.dart',
    'lib/widgets/modular_widgets/settings_widgets/addresses_settings_view.dart',
    'harness/app/agent.dart',
    'harness/app/frame_window.dart',
    'test/harness/frame_window_test.dart',
    'harness/app/capture_frame.dart',
    'test/harness/capture_frame_test.dart',
    'harness/wallet_recipe_failure.dart',
    'harness/app/recipe_control_admission.dart',
    'test/harness/recipe_control_admission_test.dart',
    'test/harness/wallet_recipe_startup_test.dart',
    'test/harness/startup_key_confirm_test.dart',
    'test/harness/startup_key_refusal_test.dart',
    'test/harness/startup_key_support.dart',
    'lib/utils/entry_capture_source.dart',
    'lib/screens/onboarding/import_wallet/import_wallet_seed_choice_screen.dart',
    'harness/app/native_entry_capture.dart',
    'harness/app/entry_capture_progress.dart',
    'test/harness/entry_capture_progress_test.dart',
    'harness/app/retained_renderer_frame.dart',
    'harness/app/retained_png.dart',
    'test/harness/retained_renderer_frame_test.dart',
    'lib/utils/original_publications.dart',
    'test/publication_session/original_publications_test.dart',
    'harness/app/readonly_sdk_admission.dart',
    'test/harness/readonly_sdk_admission_test.dart',
    'harness/app/readonly_sdk_binding.dart',
    'test/harness/readonly_sdk_binding_test.dart',
    'harness/app/readonly_native_commands.dart',
    'harness/app/activity_message_seam_binding.dart',
    'harness/app/fixtures/activity_message_preview.dart',
    'harness/app/fixtures/home_zap_preview.dart',
    'harness/app/logical_capture.dart',
    'harness/app/readonly_shot_layout.dart',
    'test/harness/logical_capture_test.dart',
    'test/harness/readonly_native_commands_test.dart',
    'harness/app/readonly_native_mode.dart',
    'harness/app/presentation_mode.dart',
    'test/harness/readonly_native_mode_test.dart',
    'test/harness/readonly_native_agent_test.dart',
    'test/originals/originals_test.dart',
    'harness/app/readonly_wallet_admission.dart',
    'harness/app/readonly_wallet_binding.dart',
    'test/harness/readonly_wallet_admission_test.dart',
    'harness/bin/readonly_inspection_session.dart',
    'harness/bin/ci_wallet_inspection.dart',
    'test/harness/readonly_inspection_session_test.dart',
    'harness/bin/readonly_viewport_probe.dart',
    'harness/bin/readonly_details_catalog.dart',
    'harness/bin/readonly_navigation_catalog.dart',
    'harness/bin/readonly_settings_catalog.dart',
    'test/harness/readonly_viewport_probe_test.dart',
    'harness/bin/screen_capture.dart',
    'test/harness/screen_capture_test.dart',
    'test/settings/display_settings_test.dart',
    'test/settings/settings_frame_test.dart',
    'test/settings/settings_switch_test.dart',
    'lib/rearchitecture/utils/widgets/page/page_strip.dart',
    'lib/widgets/modular_widgets/help_widgets/about_card.dart',
    'test/page_strip/page_strip_test.dart',
    'test/settings_about_redesign/about_settings_view_test.dart',
    'lib/rearchitecture/features/node_update/view/node_update_card.dart',
    'lib/rearchitecture/features/node_update/widgets/node_update_rows.dart',
    'test/node_update/view/node_update_card_test.dart',
    'lib/widgets/modular_widgets/settings_widgets/settings_frame.dart',
    'lib/widgets/modular_widgets/settings_widgets/settings_switch.dart',
    'lib/widgets/modular_widgets/settings_widgets/display.dart',
    'lib/widgets/modular_widgets/settings_widgets/security_settings_view.dart',
    'test/settings_security_redesign/security_settings_view_test.dart',
    'test/settings_addresses_redesign/addresses_view_test.dart',
    'lib/widgets/modular_widgets/settings_widgets/apps_settings_view.dart',
    'test/settings_apps_redesign/apps_settings_view_test.dart',
    'lib/widgets/modular_widgets/settings_widgets/wallet_settings_view.dart',
    'test/settings_wallet_redesign/wallet_settings_view_test.dart',
    'lib/utils/reference_artwork_source.dart',
    'lib/utils/wallet_maintenance_binding.dart',
    'test/wallet_maintenance/wallet_maintenance_backend_capture_test.dart',
    'test/harness/reference_artwork_owner_test.dart',
    'harness/app/ready_reference_artwork.dart',
    'test/harness/ready_reference_artwork_test.dart',
    'lib/screens/onboarding/wallet_ready_surface.dart',
    'lib/utils/wallet_ready_binding.dart',
    'test/wallet_ready/wallet_ready_test.dart',
    'test/wallet_ready/wallet_ready_capture_test.dart',
    'lib/rearchitecture/utils/widgets/entry_field.dart',
    'lib/rearchitecture/utils/widgets/go_to_palette.dart',
    'lib/widgets/reusable_widgets/app_lottie.dart',
    'lib/widgets/window_frame.dart',
    'test/window/window_frame_test.dart',
    'test/window/window_chrome_test.dart',
    'test/onboarding/entry_capture_source_test.dart',
    'test/onboarding/entry_capture_opt_in_test.dart',
    'test/onboarding/entry_prepared_draft_test.dart',
    'lib/widgets/reusable_widgets/launch_film.dart',
    'lib/widgets/reusable_widgets/launch_film_decoder.dart',
    'test/launch_film/launch_webp_frames_test.dart',
    'test/launch_film/launch_asset_test.dart',
    'test/launch_film/launch_decode_observation_test.dart',
    'test/harness/key_dispatch_test.dart',
    'test/harness/rail_navigation_test.dart',
    'test/harness/agent_input_test.dart',
    'test/harness/wallet_recipe_failure_test.dart',
    'test/harness/wallet_recipe_test.dart',
    'lib/rearchitecture/features/tokens/widgets/token_card.dart',
    'lib/rearchitecture/features/tokens/widgets/token_row_action.dart',
    'lib/rearchitecture/features/tokens/widgets/token_inline_actions.dart',
    'test/tokens_redesign/tokens_view_test.dart',
    'test/token_actions_redesign/token_inline_actions_test.dart',
    'test/token_actions_redesign/support.dart',
    'test/burn_token/token_card_test.dart',
    'lib/seams/seam.dart',
    'lib/seams/missing_services.dart',
    'test/seams/missing_services_test.dart',
)



MAX_NOTICE_INPUT = 256 * 1024
_NOTICE_CODES = frozenset((
    'argument_type_not_assignable', 'avoid_redundant_argument_values',
    'cascade_invocations', 'directives_ordering', 'invalid_assignment',
    'lines_longer_than_80_chars',
    'missing_required_argument', 'missing_whitespace_between_adjacent_strings',
    'prefer_const_constructors', 'prefer_const_declarations',
    'prefer_initializing_formals', 'unnecessary_import', 'unnecessary_lambdas',
    'unnecessary_this', 'unused_import', 'undefined_class',
    'undefined_identifier', 'undefined_method', 'undefined_named_parameter',
))
_FINDING = re.compile(
    r'^\s*(error|warning|info) - (.+?):([0-9]+):([0-9]+) - .* - '
    r'([a-z][a-z0-9_]{0,99})\s*$')


def failure_notice(raw, actual_exit, *, repo, sources=SELECTED_DART_SOURCES):
    """Project selected locations without messages, roots or unknown codes."""
    from .analysis_delta import Refused, notice_projection, relative_source

    result = dict(schema=1, scope='strict_dart_analysis', success=False,
                  qualification=False, actual_exit=actual_exit)
    refused = dict(result, status='REFUSED', diagnostics=[],
                   total_diagnostics=0, truncated=False)
    if (type(raw) is not bytes or len(raw) > MAX_NOTICE_INPUT or
            type(actual_exit) is not int or not -255 <= actual_exit <= 255):
        return refused
    rows = []
    counts = dict(error=0, warning=0, info=0)
    summary = None
    try:
        for line in raw.decode('utf-8', 'replace').splitlines():
            if len(line) > 65536:
                return refused
            match = _FINDING.fullmatch(line)
            if match:
                level, offered, row, column, code = match.groups()
                path = relative_source(offered, repo, set(sources))
                row, column = int(row), int(column)
                if not (0 < row <= 10**7 and 0 < column <= 10**7):
                    return refused
                known = code in _NOTICE_CODES
                rows.append(dict(file=path, line=row, column=column,
                                 code=code if known else 'other',
                                 unknown_code=not known, level=level))
                counts[level] += 1
            found = re.fullmatch(r'\s*([0-9]+) issues? found[.!]?\s*', line)
            if found:
                summary = int(found[1])
    except (Refused, TypeError, ValueError):
        return refused
    result.update(status='OBSERVED', counts=counts,
                  locations_complete=summary == len(rows))
    projected = notice_projection(result, rows, cap=3600)
    projected['diagnostics'] = projected.pop('groups')
    projected['total_diagnostics'] = projected.pop('total_groups')
    return projected


def main():
    """Keep the original command/exit while exposing bounded failure metadata."""
    captured = bytearray()
    overflow = False
    with subprocess.Popen(
        ['dart', 'analyze', '--fatal-infos', *SELECTED_DART_SOURCES],
        stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    ) as process:
        while chunk := process.stdout.read(65536):
            sys.stdout.buffer.write(chunk)
            if not overflow and len(captured) + len(chunk) <= MAX_NOTICE_INPUT:
                captured.extend(chunk)
            else:
                overflow = True
        actual_exit = process.wait()
    if actual_exit:
        notice = failure_notice(
            None if overflow else bytes(captured), actual_exit, repo=Path.cwd())
        print('::notice title=Strict Dart analysis::' +
              json.dumps(notice, sort_keys=True, separators=(',', ':')),
              flush=True)
    return actual_exit


if __name__ == '__main__':
    raise SystemExit(main())
