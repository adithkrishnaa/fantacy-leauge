import 'api_client.dart';
import 'auth_service.dart';
import 'betting_service.dart';
import 'club_service.dart';
import 'match_service.dart';
import 'transaction_service.dart';

export 'api_client.dart' show ApiException;

/// Single entry point for the API layer.
///
/// Small enough that a locator beats wiring five providers through the tree.
class Services {
  Services._();

  static final ApiClient api = ApiClient.instance;

  static final AuthService auth = AuthService(api);
  static final ClubService clubs = ClubService(api);
  static final MatchService matches = MatchService(api);
  static final BettingService betting = BettingService(api);
  static final TransactionService transactions = TransactionService(api);
}
