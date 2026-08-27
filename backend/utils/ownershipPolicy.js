const forbidden = (message) => {
  const error = new Error(message);
  error.statusCode = 403;
  return error;
};

const assertMatchOwnership = (user, match) => {
  if (user.userType === 'Admin') return;

  if (user.userType !== 'Manager' || match.manager !== user._id) {
    throw forbidden('Managers cannot manage a match owned by another manager');
  }
};

const assertMemberOwnership = (user, managerClub, member) => {
  if (member.userType !== 'Member') {
    throw forbidden('This operation is only allowed for a Member account');
  }

  if (user.userType === 'Admin') return;

  if (
    user.userType !== 'Manager' ||
    !managerClub ||
    managerClub.user !== user._id ||
    member.memberOf !== managerClub.id
  ) {
    throw forbidden('Managers cannot manage a Member from another club');
  }
};

module.exports = { assertMatchOwnership, assertMemberOwnership };
