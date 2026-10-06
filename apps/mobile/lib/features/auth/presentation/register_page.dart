import 'dart:async';

import 'package:flowboard/core/l10n/error_messages.dart';
import 'package:flowboard/core/l10n/l10n.dart';
import 'package:flowboard/core/router/app_router.dart';
import 'package:flowboard/features/auth/presentation/cubit/auth_form_cubit.dart';
import 'package:flowboard/features/auth/presentation/validators.dart';
import 'package:flowboard/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

const _supportedLocales = {'en', 'ru', 'kk'};

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final language = Localizations.localeOf(context).languageCode;
    unawaited(
      context.read<AuthFormCubit>().register(
        name: _name.text,
        email: _email.text,
        password: _password.text,
        locale: _supportedLocales.contains(language) ? language : 'en',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final form = context.watch<AuthFormCubit>().state;

    return AuthScaffold(
      title: l10n.authRegisterTitle,
      subtitle: l10n.authRegisterSubtitle,
      banner: form.status == FormStatus.failure
          ? AuthBanner(l10n.apiError(form.error))
          : null,
      form: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                textInputAction: TextInputAction.next,
                maxLength: 80,
                validator: l10n.validateName,
                decoration: InputDecoration(
                  labelText: l10n.authNameLabel,
                  border: const OutlineInputBorder(),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                autocorrect: false,
                validator: l10n.validateEmail,
                decoration: InputDecoration(
                  labelText: l10n.authEmailLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _password,
                label: l10n.authPasswordLabel,
                showLabel: l10n.authShowPassword,
                hideLabel: l10n.authHidePassword,
                validator: l10n.validateNewPassword,
                onSubmitted: _submit,
                autofillHints: const [AutofillHints.newPassword],
              ),
            ],
          ),
        ),
      ),
      primaryAction: SubmitButton(
        label: l10n.authSignUp,
        loading: form.isSubmitting,
        onPressed: _submit,
      ),
      secondaryAction: TextButton(
        onPressed: () => context.goNamed(
          AppRoutes.login,
          queryParameters: GoRouterState.of(context).uri.queryParameters,
        ),
        child: Text(l10n.authHaveAccount),
      ),
    );
  }
}
