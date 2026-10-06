import 'package:equatable/equatable.dart';
import 'package:flowboard/core/network/api_exception.dart';
import 'package:flowboard/features/auth/domain/auth_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum FormStatus { idle, submitting, failure, success }

class AuthFormState extends Equatable {
  const AuthFormState({this.status = FormStatus.idle, this.error});

  final FormStatus status;
  final ApiErrorCode? error;

  bool get isSubmitting => status == FormStatus.submitting;

  @override
  List<Object?> get props => [status, error];
}

/// Submits login/registration. Navigation happens via AuthCubit + router.
class AuthFormCubit extends Cubit<AuthFormState> {
  AuthFormCubit(this._repository) : super(const AuthFormState());

  final AuthRepository _repository;

  Future<void> login({required String email, required String password}) =>
      _submit(
        () => _repository.login(email: email.trim(), password: password),
      );

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String locale,
  }) => _submit(
    () => _repository.register(
      name: name.trim(),
      email: email.trim(),
      password: password,
      locale: locale,
    ),
  );

  Future<void> _submit(Future<void> Function() action) async {
    if (state.isSubmitting) return;
    emit(const AuthFormState(status: FormStatus.submitting));
    try {
      await action();
      if (!isClosed) emit(const AuthFormState(status: FormStatus.success));
    } on ApiException catch (e) {
      if (!isClosed) {
        emit(AuthFormState(status: FormStatus.failure, error: e.code));
      }
    }
  }
}
