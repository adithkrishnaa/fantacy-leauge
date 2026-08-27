const asyncHandler = require('express-async-handler');
const prisma = require('../config/prisma');
const { assertMatchOwnership } = require('../utils/ownershipPolicy');
const { normalizeResultScores } = require('../utils/resultPolicy');

// @desc    Get a single result by ID
// @route   GET /api/results/:id
// @access  Private/Admin
const getResultById = asyncHandler(async (req, res) => {
  const result = await prisma.result.findUnique({ where: { id: req.params.id } });
  if (!result) {
    res.status(404);
    throw new Error("Result not found");
  }
  res.json({ ...result, _id: result.id });
});

// @desc    Add result for a match
// @route   POST /api/results
// @access  Private/Manager
const addResult = asyncHandler(async (req, res) => {
  const { matchId, team1Scores, team2Scores } = req.body;

  const match = await prisma.match.findUnique({ where: { id: matchId } });
  if (!match) {
    res.status(404);
    throw new Error('Match not found');
  }
  assertMatchOwnership(req.user, match);

  const normalized = normalizeResultScores(team1Scores, team2Scores);

  const resultId = require('crypto').randomUUID();
  const result = await prisma.result.create({
    data: {
      id: resultId,
      match: matchId,
      team1Scores: normalized.team1Scores,
      team2Scores: normalized.team2Scores,
    }
  });

  await prisma.match.update({
    where: { id: matchId },
    data: { result: result.id, status: 'Ongoing' }
  });

  await calculateBetScores(matchId, normalized.team1Scores, normalized.team2Scores);

  res.status(201).json({ ...result, _id: result.id });
});

// @desc    Update result for a match
// @route   PUT /api/results/:id
// @access  Private/Manager
const updateResult = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { team1Scores, team2Scores } = req.body;
  const normalized = normalizeResultScores(team1Scores, team2Scores);

  const result = await prisma.result.findUnique({ where: { id } });

  if (!result) {
    res.status(404);
    throw new Error('Result not found');
  }

  const match = await prisma.match.findUnique({ where: { id: result.match } });
  if (!match) {
    res.status(404);
    throw new Error('Match not found');
  }
  assertMatchOwnership(req.user, match);

  const updatedResult = await prisma.result.update({
    where: { id },
    data: {
      team1Scores: normalized.team1Scores,
      team2Scores: normalized.team2Scores,
    }
  });

  await calculateBetScores(result.match, normalized.team1Scores, normalized.team2Scores);

  res.json({ ...updatedResult, _id: updatedResult.id });
});

// @desc    Calculate bet scores for a match
// @access  Private
const calculateBetScores = async (matchId, team1Scores, team2Scores) => {
  const groups = await prisma.group.findMany({ where: { match: matchId } });

  for (const group of groups) {
    const bets = await prisma.bet.findMany({ where: { group: group.id } });

    for (const bet of bets) {
      const combination = bet.combination;
      let totalScore = 0;

      for (let i = 0; i < combination.length; i++) {
        const char = combination[i];
        if (/\d/.test(char)) {
          const playerIndex = parseInt(char) - 1;
          totalScore += (team1Scores[playerIndex] || 0);
        } else if (/[A-G]/.test(char)) {
          const playerIndex = char.charCodeAt(0) - 65;
          totalScore += (team2Scores[playerIndex] || 0);
        }
      }

      await prisma.bet.update({
        where: { id: bet.id },
        data: { score: totalScore }
      });
    }
  }
};

module.exports = { addResult, updateResult, getResultById };
