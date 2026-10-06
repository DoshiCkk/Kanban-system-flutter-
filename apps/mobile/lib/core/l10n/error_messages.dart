import 'package:flowboard/core/l10n/l10n.dart';
import 'package:flowboard/core/network/api_exception.dart';

extension ApiErrorMessage on AppLocalizations {
  String apiError(ApiErrorCode? code) => switch (code) {
    ApiErrorCode.network => errorNetwork,
    ApiErrorCode.invalidCredentials => errorInvalidCredentials,
    ApiErrorCode.emailTaken => errorEmailTaken,
    ApiErrorCode.invalidRefreshToken ||
    ApiErrorCode.unauthorized => errorSessionExpired,
    ApiErrorCode.rateLimited => errorRateLimited,
    ApiErrorCode.forbidden => errorForbidden,
    ApiErrorCode.notFound => errorNotFound,
    ApiErrorCode.inviteInvalid => errorInviteInvalid,
    ApiErrorCode.ownerRoleLocked => errorOwnerRoleLocked,
    ApiErrorCode.validationFailed => errorValidation,
    ApiErrorCode.server => errorServer,
    ApiErrorCode.conflict || ApiErrorCode.unknown || null => errorUnknown,
  };
}
