import 'package:flutter_test/flutter_test.dart';

import 'package:fantasy_league/models/bet.dart';
import 'package:fantasy_league/models/json_utils.dart';
import 'package:fantasy_league/models/user.dart';

void main() {
  group('json_utils', () {
    test('idOf prefers the _id alias the backend adds for the frontend', () {
      expect(idOf({'_id': 'abc', 'id': 'xyz'}), 'abc');
      expect(idOf({'id': 'xyz'}), 'xyz');
      expect(idOf({}), '');
    });

    test('relationId handles populated objects and bare id strings', () {
      expect(relationId('club-1'), 'club-1');
      expect(relationId({'id': 'club-2', 'clubName': 'Falcons'}), 'club-2');
      expect(relationId(null), isNull);
    });

    test('asDouble tolerates int, double and string amounts', () {
      expect(asDouble(5), 5.0);
      expect(asDouble(5.5), 5.5);
      expect(asDouble('7.25'), 7.25);
      expect(asDouble(null), 0.0);
      expect(asDouble('not a number', 3), 3.0);
    });
  });

  group('AppUser', () {
    test('parses the login payload', () {
      final user = AppUser.fromJson({
        '_id': 'u1',
        'firstName': 'Asha',
        'email': 'asha@example.com',
        'userType': 'Member',
        'credits': 250,
      });

      expect(user.id, 'u1');
      expect(user.role, UserRole.member);
      expect(user.credits, 250.0);
      // The login response omits memberOf, so the member has no club yet.
      expect(user.hasClub, isFalse);
    });

    test('parses the profile payload with a populated club', () {
      final user = AppUser.fromJson({
        'id': 'u2',
        'firstName': 'Ravi',
        'lastName': 'Kumar',
        'userType': 'Manager',
        'memberOf': {'_id': 'c1', 'clubName': 'Falcons'},
      });

      expect(user.fullName, 'Ravi Kumar');
      expect(user.role, UserRole.manager);
      expect(user.memberOfId, 'c1');
      expect(user.memberOfName, 'Falcons');
      expect(user.hasClub, isTrue);
    });

    test('unrecognised userType does not crash parsing', () {
      final user = AppUser.fromJson({'id': 'u3', 'userType': 'Robot'});
      expect(user.role, UserRole.unknown);
    });
  });

  group('Bet', () {
    test('canonical sorts characters the way the backend compares them', () {
      const bet = Bet(
        id: 'b1',
        betAmount: 100,
        matchId: 'm1',
        groupId: 'g1',
        betterId: 'u1',
        combination: 'C1A',
      );
      // placeBet does combination.split('').sort().join('') before comparing.
      expect(bet.canonical, '1AC');
      expect(bet.symbols, ['C', '1', 'A']);
    });

    test(r'symbol set matches the backend regex ^[1-7A-G]{3}$', () {
      expect(kCombinationLength, 3);
      expect(kCombinationSymbols.length, 14);
      for (final symbol in kCombinationSymbols) {
        expect(RegExp(r'^[1-7A-G]$').hasMatch(symbol), isTrue,
            reason: '$symbol is not a valid combination symbol');
      }
    });
  });
}
