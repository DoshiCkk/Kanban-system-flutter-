import 'package:flowboard/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

void main() {
  group(AuthCubit, () {
    test('starts from the restored user', () async {
      final cubit = AuthCubit(FakeAuthRepository(user: testUser));
      expect(cubit.state, const AuthState(user: testUser));
      await cubit.close();
    });

    test('server-side expiry is flagged, user logout is not', () async {
      final repo = FakeAuthRepository(user: testUser);
      final cubit = AuthCubit(repo);

      repo.expireSession();
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state, const AuthState(sessionExpired: true));

      await repo.login(email: testUser.email, password: 'x');
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.isAuthenticated, isTrue);
      expect(cubit.state.sessionExpired, isFalse);

      await cubit.logout();
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state, const AuthState());

      await cubit.close();
    });
  });
}
