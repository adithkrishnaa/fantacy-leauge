const assertTransactionReadAccess = (user, requestedUserId) => {
  if (user.userType === 'Admin' || user._id === requestedUserId) return;
  const error = new Error('Users can only view their own transaction history');
  error.statusCode = 403;
  throw error;
};

module.exports = { assertTransactionReadAccess };
