const test = require('node:test');
const assert = require('node:assert/strict');
const { normalizeResultScores, assertResultExistsForPayout } = require('../utils/resultPolicy');

test('normalizes seven numeric scores for each team', () => {
  assert.deepEqual(
    normalizeResultScores(['1', 2, 3, 4, 5, 6, 7], [7, 6, 5, 4, 3, 2, '1']),
    { team1Scores: [1, 2, 3, 4, 5, 6, 7], team2Scores: [7, 6, 5, 4, 3, 2, 1] },
  );
});

for (const [name, team1, team2] of [
  ['rejects missing score arrays', undefined, []],
  ['rejects arrays that do not contain seven scores', [1], [1, 2, 3, 4, 5, 6, 7]],
  ['rejects non-numeric scores', [1, 2, 3, 4, 5, 6, 'x'], [1, 2, 3, 4, 5, 6, 7]],
  ['rejects negative scores', [1, 2, 3, 4, 5, 6, -1], [1, 2, 3, 4, 5, 6, 7]],
]) {
  test(name, () => assert.throws(() => normalizeResultScores(team1, team2), /seven non-negative integer scores/i));
}

test('rejects payout when the match has no saved result', () => {
  assert.throws(() => assertResultExistsForPayout({ result: null }), /saved result/i);
});

test('accepts payout validation when a saved result is linked', () => {
  assert.doesNotThrow(() => assertResultExistsForPayout({ result: 'result-1' }));
});
