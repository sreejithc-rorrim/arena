/// The signed-in staff member's own details and the arena's staff terms.
/// Online only.
library;

import 'package:arena_ops/core/result/result.dart';
import 'package:arena_ops/domain/profile/staff_details.dart';
import 'package:arena_ops/domain/profile/staff_terms.dart';

abstract interface class ProfileRepository {
  /// [StaffDetails.empty] when nothing was saved yet.
  Future<Result<StaffDetails>> myDetails();

  Future<Result<void>> saveDetails(StaffDetailsCommand cmd);

  /// The version in force and whether the signed-in member accepted it.
  Future<Result<TermsStatus>> termsStatus();

  /// Returns the server's accepted_at.
  Future<Result<DateTime>> acceptTerms(TermsAcceptCommand cmd);
}
