import 'dart:async';

import 'package:flowboard/core/l10n/error_messages.dart';
import 'package:flowboard/core/l10n/l10n.dart';
import 'package:flowboard/core/router/app_router.dart';
import 'package:flowboard/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:flowboard/features/auth/presentation/cubit/auth_form_cubit.dart';
import 'package:flowboard/features/auth/presentation/validators.dart';
import 'package:flowboard/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    unawaited(
      context.read<AuthFormCubit>().login(
        email: _email.text,
        password: _password.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final form = context.watch<AuthFormCubit>().state;
    final sessionExpired = context.select<AuthCubit, bool>(
      (c) => c.state.sessionExpired,
    );

    final bannerText = form.status == FormStatus.failure
        ? l10n.apiError(form.error)
        : sessionExpired
        ? l10n.errorSessionExpired
        : null;

    return AuthScaffold(
      title: l10n.authLoginTitle,
      subtitle: l10n.authLoginSubtitle,
      banner: bannerText == null ? null : AuthBanner(bannerText),
      form: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
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
                validator: l10n.validateLoginPassword,
                onSubmitted: _submit,
              ),
            ],
          ),
        ),
      ),
      primaryAction: SubmitButton(
        label: l10n.authSignIn,
        loading: form.isSubmitting,
        onPressed: _submit,
      ),
      secondaryAction: TextButton(
        onPressed: () => context.goNamed(
          AppRoutes.register,
          queryParameters: GoRouterState.of(context).uri.queryParameters,
        ),
        child: Text(l10n.authNoAccount),
      ),
    );
  }
}
