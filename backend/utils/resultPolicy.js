const badRequest = (message) => {
  const error = new Error(message);
  error.statusCode = 400;
  throw error;
};

const normalizeResultScores = (team1Scores, team2Scores) => {
  const valid = (scores) => Array.isArray(scores) && scores.length === 7 && scores.every((score) => {
    const value = Number(score);
    return Number.isInteger(value) && value >= 0;
  });
  if (!valid(team1Scores) || !valid(team2Scores)) {
    badRequest('Each team must have exactly seven non-negative integer scores');
  }
  return { team1Scores: team1Scores.map(Number), team2Scores: team2Scores.map(Number) };
};

const assertResultExistsForPayout = (match) => {
  if (!match.result) badRequest('A saved result is required before approving prize credits');
};

module.exports = { normalizeResultScores, assertResultExistsForPayout };
