const test = require('node:test');
const assert = require('node:assert/strict');
const { buildPlayerUpdate } = require('../utils/playerFields');

test('maps the API player payload to the Match JSON field names', () => {
  const team1Players = { 0: 'Alice', 1: 'Bea' };
  const team2Players = { 0: 'Chris', 1: 'Dev' };

  assert.deepEqual(buildPlayerUpdate(team1Players, team2Players), {
    Team1Players: team1Players,
    Team2Players: team2Players,
  });
});

test('rejects missing player objects', () => {
  assert.throws(
    () => buildPlayerUpdate(undefined, {}),
    /Both team player lists are required/,
  );
});
