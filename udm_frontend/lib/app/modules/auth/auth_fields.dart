import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/widgets/app_kit.dart';
import 'validators.dart';

/// The two forms share their fields so a label, a rule and an error read the
/// same way on both screens.
class EmailField extends StatelessWidget {
  const EmailField({super.key, required this.controller, this.autofocus = false});

  final TextEditingController controller;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => TextFormField(
        key: const Key('udm.emailField'),
        controller: controller,
        autofocus: autofocus,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.email],
        decoration: InputDecoration(
          labelText: 'Email'.tr,
          hintText: 'you@udm.ac.ug',
          prefixIcon: const Icon(AppIcons.mail),
        ),
        validator: AuthValidators.email,
      );
}

class NameField extends StatelessWidget {
  const NameField({super.key, required this.controller, this.autofocus = false});

  final TextEditingController controller;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => TextFormField(
        key: const Key('udm.nameField'),
        controller: controller,
        autofocus: autofocus,
        textCapitalization: TextCapitalization.words,
        maxLength: AuthValidators.maximumNameLength,
        decoration: InputDecoration(
          labelText: 'Full name'.tr,
          prefixIcon: const Icon(AppIcons.person),
        ),
        validator: AuthValidators.fullName,
      );
}

class PasswordField extends StatelessWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.revealed,
    this.label = 'Password',
    this.validator,
    this.autofillHints,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final RxBool revealed;
  final String label;
  final String? Function(String?)? validator;
  final List<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => Obx(
        () => TextFormField(
          key: Key('udm.passwordField.$label'),
          controller: controller,
          obscureText: !revealed.value,
          textInputAction: TextInputAction.done,
          autofillHints: autofillHints,
          maxLength: 128,
          decoration: InputDecoration(
            labelText: label.tr,

            prefixIcon: const Icon(AppIcons.lock),
            counterText: '',
            suffixIcon: IconButton(
              onPressed: () => revealed.value = !revealed.value,
              tooltip: revealed.value ? 'Hide password'.tr : 'Show password'.tr,
              icon: Icon(revealed.value ? AppIcons.eyeOff : AppIcons.eye),
            ),
          ),
          validator: validator ?? AuthValidators.password,
          onFieldSubmitted: onSubmitted,
        ),
      );
}
