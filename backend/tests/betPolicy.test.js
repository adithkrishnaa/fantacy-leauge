const test = require('node:test');
const assert = require('node:assert/strict');
const { validateBetContext } = require('../utils/betPolicy');

const valid = {
  amount: 100,
  user: { userType: 'Member', memberOf: 'club-1' },
  match: { id: 'match-1', club: 'club-1', status: 'Active' },
  group: { match: 'match-1', status: 'Active', betAmount: 100 },
};

test('accepts a configured bet for an active group in the Members club', () => {
  assert.doesNotThrow(() => validateBetContext(valid));
});

for (const [name, change, message] of [
  ['rejects zero and negative amounts', { amount: 0 }, /positive/],
  ['rejects an amount different from the configured group amount', { amount: 50 }, /configured/],
  ['rejects a group belonging to another match', { group: { ...valid.group, match: 'match-2' } }, /match/],
  ['rejects an inactive group', { group: { ...valid.group, status: 'Inactive' } }, /group is not active/i],
  ['rejects a match that is no longer open for betting', { match: { ...valid.match, status: 'Ongoing' } }, /match is not active/i],
  ['rejects a Member outside the matchs club', { user: { ...valid.user, memberOf: 'club-2' } }, /club/],
]) {
  test(name, () => {
    assert.throws(() => validateBetContext({ ...valid, ...change }), message);
  });
}
