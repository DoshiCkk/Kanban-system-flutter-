import 'package:flowboard/core/l10n/l10n.dart';

/// Must match the API's PASSWORD_MIN.
const passwordMinLength = 8;

final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

extension AuthValidators on AppLocalizations {
  String? validateEmail(String? value) =>
      _emailPattern.hasMatch(value?.trim() ?? '')
      ? null
      : validationEmailInvalid;

  String? validateLoginPassword(String? value) =>
      (value ?? '').isEmpty ? validationPasswordRequired : null;

  String? validateNewPassword(String? value) =>
      (value ?? '').length < passwordMinLength
      ? validationPasswordTooShort(passwordMinLength)
      : null;

  String? validateName(String? value) =>
      (value ?? '').trim().isEmpty ? validationNameRequired : null;
}
