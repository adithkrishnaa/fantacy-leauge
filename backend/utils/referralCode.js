const crypto = require('crypto');

const generateUniqueReferralCode = async (users, randomBytes = crypto.randomBytes) => {
  while (true) {
    const referralCode = randomBytes(4).toString('hex').toUpperCase();
    const existingUser = await users.findUnique({ where: { referralCode } });

    if (!existingUser) {
      return referralCode;
    }
  }
};

const ensureUserReferralCode = async (users, user, randomBytes = crypto.randomBytes) => {
  if (user.referralCode) {
    return user.referralCode;
  }

  const referralCode = await generateUniqueReferralCode(users, randomBytes);
  const result = await users.updateMany({
    where: { id: user.id, referralCode: null },
    data: { referralCode },
  });

  if (result.count === 1) {
    return referralCode;
  }

  const updatedUser = await users.findUnique({
    where: { id: user.id },
    select: { referralCode: true },
  });

  return updatedUser.referralCode;
};

module.exports = { generateUniqueReferralCode, ensureUserReferralCode };
