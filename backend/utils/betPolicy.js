const reject = (message, statusCode = 400) => {
  const error = new Error(message);
  error.statusCode = statusCode;
  throw error;
};

const validateBetContext = ({ amount, user, match, group }) => {
  if (!Number.isFinite(amount) || amount <= 0) reject('Bet amount must be a positive number');
  if (amount !== group.betAmount) reject('Bet amount must equal the configured group amount');
  if (group.match !== match.id) reject('Betting group does not belong to the selected match');
  if (group.status !== 'Active') reject('Betting group is not active');
  if (match.status !== 'Active') reject('Match is not active for betting');
  if (user.userType !== 'Member' || !user.memberOf || user.memberOf !== match.club) {
    reject('Member does not belong to this matchs club', 403);
  }
};

module.exports = { validateBetContext };
