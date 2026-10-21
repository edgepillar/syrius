import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:stacked/stacked.dart';
import 'package:zenon_syrius_wallet_flutter/blocs/blocs.dart';
import 'package:zenon_syrius_wallet_flutter/main.dart';
import 'package:zenon_syrius_wallet_flutter/rearchitecture/utils/widgets/motion/motion.dart';
import 'package:zenon_syrius_wallet_flutter/utils/utils.dart';
import 'package:zenon_syrius_wallet_flutter/widgets/reusable_widgets/custom_material_stepper.dart'
    as custom_material_stepper;
import 'package:zenon_syrius_wallet_flutter/widgets/widgets.dart';
import 'package:znn_sdk_dart/znn_sdk_dart.dart';

/// The steps of creating an Accelerator project.
enum ProjectCreationStep {
  /// The address that will own the project, and the fee it pays.
  projectCreation,

  /// The project's name, description, link and budget.
  projectDetails,

  /// Sending it.
  submitProject,
}

/// Creates an Accelerator project owned by the selected address.
class ProjectCreationStepper extends StatefulWidget {
  /// Creates the stepper.
  const ProjectCreationStepper({super.key});

  @override
  State<ProjectCreationStepper> createState() => _ProjectCreationStepperState();
}

class _ProjectCreationStepperState extends State<ProjectCreationStepper> {
  ProjectCreationStep? _lastCompletedStep;
  ProjectCreationStep _currentStep = ProjectCreationStep.values.first;

  final TextEditingController _addressController = TextEditingController();
  TextEditingController _projectNameController = TextEditingController();
  TextEditingController _projectDescriptionController = TextEditingController();
  TextEditingController _projectUrlController = TextEditingController();
  TextEditingController _projectZnnAmountController = TextEditingController();
  TextEditingController _projectQsrAmountController = TextEditingController();

  GlobalKey<FormState> _projectNameKey = GlobalKey();
  GlobalKey<FormState> _projectDescriptionKey = GlobalKey();
  GlobalKey<FormState> _projectUrlKey = GlobalKey();
  GlobalKey<FormState> _projectZnnKey = GlobalKey();
  GlobalKey<FormState> _projectQsrKey = GlobalKey();

  final GlobalKey<LoadingButtonState> _submitButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _addressController.text = kSelectedAddress!;
    unawaited(sl.get<BalanceBloc>().getBalanceForAllAddresses());
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, AccountInfo>?>(
      stream: sl.get<BalanceBloc>().stream,
      builder: (_, AsyncSnapshot<Map<String, AccountInfo>?> snapshot) {
        final Widget state;
        if (snapshot.hasError) {
          state = SyriusErrorWidget(
            snapshot.error!,
            key: const ValueKey<String>('error'),
          );
        } else if (snapshot.connectionState == ConnectionState.active &&
            snapshot.hasData) {
          state = KeyedSubtree(
            key: const ValueKey<String>('steps'),
            child: _buildBody(
              context,
              snapshot.data![_addressController.text]!,
            ),
          );
        } else {
          state = const AccStepperLoading(key: ValueKey<String>('loading'));
        }
        return StateSwitcher(child: state);
      },
    );
  }

  Widget _buildBody(BuildContext context, AccountInfo accountInfo) {
    return AccStepperFrame(
      isDone: _lastCompletedStep == ProjectCreationStep.values.last,
      againLabel: 'Create another',
      onAgain: () {
        _clearInput();
        setState(() {
          _currentStep = ProjectCreationStep.values.first;
          _lastCompletedStep = null;
        });
      },
      doneLabel: 'View projects',
      onDone: () {
        Navigator.pop(context);
      },
      stepper: custom_material_stepper.Stepper(
        currentStep: _currentStep.index,
        onStepTapped: (int index) {},
        steps: <custom_material_stepper.Step>[
          StepperUtils.getMaterialStep(
            stepTitle: 'Owner',
            stepContent: _buildOwnerStep(accountInfo),
            stepSubtitle: _addressController.text,
            stepState: StepperUtils.getStepState(
              ProjectCreationStep.projectCreation.index,
              _lastCompletedStep?.index,
            ),
            context: context,
          ),
          StepperUtils.getMaterialStep(
            stepTitle: 'Details',
            stepContent: _buildDetailsStep(),
            stepSubtitle:
                '${_projectNameController.text} · '
                '${_projectZnnAmountController.text} ${kZnnCoin.symbol} · '
                '${_projectQsrAmountController.text} ${kQsrCoin.symbol}',
            stepState: StepperUtils.getStepState(
              ProjectCreationStep.projectDetails.index,
              _lastCompletedStep?.index,
            ),
            context: context,
          ),
          StepperUtils.getMaterialStep(
            stepTitle: 'Submit',
            stepContent: _buildSubmitStep(),
            stepSubtitle: 'Submitted',
            stepState: StepperUtils.getStepState(
              ProjectCreationStep.submitProject.index,
              _lastCompletedStep?.index,
            ),
            context: context,
          ),
        ],
      ),
    );
  }

  void _clearInput() {
    _projectNameController = TextEditingController();
    _projectDescriptionController = TextEditingController();
    _projectUrlController = TextEditingController();
    _projectZnnAmountController = TextEditingController();
    _projectQsrAmountController = TextEditingController();
    _projectNameKey = GlobalKey();
    _projectDescriptionKey = GlobalKey();
    _projectUrlKey = GlobalKey();
    _projectZnnKey = GlobalKey();
    _projectQsrKey = GlobalKey();
  }

  /// The creation fee, as "1 ZNN".
  String get _fee =>
      accAmount(projectCreationFeeInZnn, coinDecimals, kZnnCoin.symbol);

  Widget _buildOwnerStep(AccountInfo accountInfo) {
    return FocusTraversalGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AccField(
            label: 'Owner',
            child: DisabledAddressField(_addressController),
          ),
          AccBalanceLine(kZnnCoin, accountInfo),
          const SizedBox(height: kAccFieldGap),
          DottedBorderInfoWidget(
            text: 'Creating a project costs $_fee, paid to the Accelerator',
          ),
          AccStepActions(
            primary: StepperButton(
              onPressed:
                  accountInfo.getBalance(
                        kZnnCoin.tokenStandard,
                      ) >=
                      projectCreationFeeInZnn
                  ? () {
                      setState(() {
                        _lastCompletedStep =
                            ProjectCreationStep.projectCreation;
                        _currentStep = ProjectCreationStep.projectDetails;
                      });
                    }
                  : null,
              text: 'Continue',
            ),
            secondaryLabel: 'Cancel',
            onSecondary: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsStep() {
    final TextStyle text = accFieldTextStyle(context);
    final TextStyle amount = accFieldTextStyle(context, mono: true);
    return FocusTraversalGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AccField(
            label: 'Name',
            child: Form(
              key: _projectNameKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: InputField(
                controller: _projectNameController,
                inputtedTextStyle: text,
                onChanged: (String value) {
                  setState(() {});
                },
                validator: Validations.projectName,
              ),
            ),
          ),
          const SizedBox(height: kAccFieldGap),
          AccField(
            label: 'Description',
            child: Form(
              key: _projectDescriptionKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: InputField(
                controller: _projectDescriptionController,
                inputtedTextStyle: text,
                onChanged: (String value) {
                  setState(() {});
                },
                validator: Validations.projectDescription,
              ),
            ),
          ),
          const SizedBox(height: kAccFieldGap),
          AccField(
            label: 'URL',
            help: 'Link to the project article',
            child: Form(
              key: _projectUrlKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: InputField(
                controller: _projectUrlController,
                hintText: 'https://',
                inputtedTextStyle: text,
                onChanged: (String value) {
                  setState(() {});
                },
                validator: InputValidators.checkUrl,
              ),
            ),
          ),
          const SizedBox(height: kAccFieldGap),
          AccField(
            label: 'ZNN budget',
            child: Form(
              key: _projectZnnKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: InputField(
                inputFormatters: FormatUtils.getAmountTextInputFormatters(
                  _projectZnnAmountController.text,
                ),
                controller: _projectZnnAmountController,
                hintText: '0.0',
                inputtedTextStyle: amount,
                suffixIcon: AmountSuffixWidgets(
                  kZnnCoin,
                  onMaxPressed: () {
                    final BigInt maxZnn = kZnnProjectMaximumFunds;
                    if (_projectZnnAmountController.text.isEmpty ||
                        _projectZnnAmountController.text.extractDecimals(
                              coinDecimals,
                            ) <
                            maxZnn) {
                      setState(() {
                        _projectZnnAmountController.text = maxZnn.addDecimals(
                          coinDecimals,
                        );
                      });
                    }
                  },
                ),
                validator: (String? value) => InputValidators.correctValue(
                  value,
                  kZnnProjectMaximumFunds,
                  kZnnCoin.decimals,
                  kZnnProjectMinimumFunds,
                  canBeEqualToMin: true,
                ),
                onChanged: (String value) {
                  setState(() {});
                },
              ),
            ),
          ),
          const SizedBox(height: kAccFieldGap),
          AccField(
            label: 'QSR budget',
            child: Form(
              key: _projectQsrKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: InputField(
                inputFormatters: FormatUtils.getAmountTextInputFormatters(
                  _projectQsrAmountController.text,
                ),
                controller: _projectQsrAmountController,
                hintText: '0.0',
                inputtedTextStyle: amount,
                suffixIcon: AmountSuffixWidgets(
                  kQsrCoin,
                  onMaxPressed: () {
                    final BigInt maxQsr = kQsrProjectMaximumFunds;
                    if (_projectQsrAmountController.text.isEmpty ||
                        _projectQsrAmountController.text.extractDecimals(
                              coinDecimals,
                            ) <
                            maxQsr) {
                      setState(() {
                        _projectQsrAmountController.text = maxQsr.addDecimals(
                          coinDecimals,
                        );
                      });
                    }
                  },
                ),
                validator: (String? value) => InputValidators.correctValue(
                  value,
                  kQsrProjectMaximumFunds,
                  kQsrCoin.decimals,
                  kQsrProjectMinimumFunds,
                  canBeEqualToMin: true,
                ),
                onChanged: (String value) {
                  setState(() {});
                },
              ),
            ),
          ),
          AccStepActions(
            primary: StepperButton(
              text: 'Continue',
              onPressed: _areInputDetailsValid()
                  ? () {
                      setState(() {
                        _lastCompletedStep = ProjectCreationStep.projectDetails;
                        _currentStep = ProjectCreationStep.submitProject;
                      });
                    }
                  : null,
            ),
            secondaryLabel: 'Cancel',
            onSecondary: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        DottedBorderInfoWidget(text: 'Submitting costs $_fee'),
        AccStepActions(
          primary: _buildSubmitProjectViewModel(),
          secondaryLabel: 'Back',
          onSecondary: () {
            setState(() {
              _currentStep = ProjectCreationStep.projectDetails;
              _lastCompletedStep = ProjectCreationStep.projectCreation;
            });
          },
        ),
      ],
    );
  }

  Widget _buildSubmitProjectViewModel() {
    return ViewModelBuilder<CreateProjectBloc>.reactive(
      onViewModelReady: (CreateProjectBloc model) {
        model.stream.listen(
          (AccountBlockTemplate? event) {
            if (event != null) {
              _submitButtonKey.currentState?.animateReverse();
              setState(() {
                _lastCompletedStep = ProjectCreationStep.submitProject;
              });
            }
          },
          onError: (Object error) async {
            _submitButtonKey.currentState?.animateReverse();
            await NotificationUtils.sendNotificationError(
              error,
              'Error while submitting project',
            );
          },
        );
      },
      builder: (_, CreateProjectBloc model, _) =>
          _buildSubmitProjectButton(model),
      viewModelBuilder: CreateProjectBloc.new,
    );
  }

  Widget _buildSubmitProjectButton(CreateProjectBloc model) {
    return LoadingButton(
      onPressed: () {
        _submitButtonKey.currentState?.animateForward();
        model.createProject(
          _projectNameController.text,
          _projectDescriptionController.text,
          _projectUrlController.text,
          _projectZnnAmountController.text.extractDecimals(
            coinDecimals,
          ),
          _projectQsrAmountController.text.extractDecimals(
            coinDecimals,
          ),
        );
      },
      text: 'Submit',
      circularBorderRadius: kLoadingButtonMinSize.height / 2,
      key: _submitButtonKey,
    );
  }

  bool _areInputDetailsValid() =>
      Validations.projectName(
            _projectNameController.text,
          ) ==
          null &&
      Validations.projectDescription(
            _projectDescriptionController.text,
          ) ==
          null &&
      InputValidators.checkUrl(
            _projectUrlController.text,
          ) ==
          null &&
      InputValidators.correctValue(
            _projectZnnAmountController.text,
            kZnnProjectMaximumFunds,
            kZnnCoin.decimals,
            kZnnProjectMinimumFunds,
            canBeEqualToMin: true,
          ) ==
          null &&
      InputValidators.correctValue(
            _projectQsrAmountController.text,
            kQsrProjectMaximumFunds,
            kZnnCoin.decimals,
            kQsrProjectMinimumFunds,
            canBeEqualToMin: true,
          ) ==
          null;

  @override
  void dispose() {
    _addressController.dispose();
    _projectNameController.dispose();
    _projectDescriptionController.dispose();
    _projectUrlController.dispose();
    _projectZnnAmountController.dispose();
    _projectQsrAmountController.dispose();
    super.dispose();
  }
}
