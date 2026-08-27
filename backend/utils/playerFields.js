const buildPlayerUpdate = (team1Players, team2Players) => {
  if (!team1Players || !team2Players || typeof team1Players !== 'object' || typeof team2Players !== 'object') {
    throw new Error('Both team player lists are required');
  }

  return {
    Team1Players: team1Players,
    Team2Players: team2Players,
  };
};

module.exports = { buildPlayerUpdate };
