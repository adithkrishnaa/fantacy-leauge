const REFERRAL_REGISTRATION_REWARD = 100;

const applyRegistrationReferralReward = async (users, transactions, options) => {
  const { referrerId, newMemberName, transactionId } = options;
  await users.update({
    where: { id: referrerId },
    data: {
      credits: { increment: REFERRAL_REGISTRATION_REWARD },
      referralCount: { increment: 1 },
      referralEarnings: { increment: REFERRAL_REGISTRATION_REWARD },
    },
  });
  await transactions.create({
    data: {
      id: transactionId,
      transactionId: `REFERRAL-${transactionId}`,
      user: referrerId,
      amount: REFERRAL_REGISTRATION_REWARD,
      type: 'Credit',
      description: `Referral registration reward for ${newMemberName}`,
    },
  });
};

const calculateReferralWinCommission = () => 0;

module.exports = {
  REFERRAL_REGISTRATION_REWARD,
  applyRegistrationReferralReward,
  calculateReferralWinCommission,
};
