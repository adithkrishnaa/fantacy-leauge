const test = require('node:test');
const assert = require('node:assert/strict');
const {
  REFERRAL_REGISTRATION_REWARD,
  applyRegistrationReferralReward,
  calculateReferralWinCommission,
} = require('../utils/referralReward');

test('credits a fixed 100 reward and increments the referral count', async () => {
  const state = { credits: 20, referralCount: 1, transactions: [] };
  const users = {
    update: async ({ data }) => {
      state.credits += data.credits.increment;
      state.referralCount += data.referralCount.increment;
    },
  };
  const transactions = {
    create: async ({ data }) => state.transactions.push(data),
  };

  await applyRegistrationReferralReward(users, transactions, {
    referrerId: 'referrer-1',
    newMemberName: 'New Member',
    transactionId: 'reward-txn-1',
  });

  assert.equal(REFERRAL_REGISTRATION_REWARD, 100);
  assert.equal(state.credits, 120);
  assert.equal(state.referralCount, 2);
  assert.equal(state.transactions.length, 1);
  assert.equal(state.transactions[0].amount, 100);
  assert.equal(state.transactions[0].type, 'Credit');
});

test('does not deduct a referral commission from later winnings', () => {
  assert.equal(calculateReferralWinCommission(1000), 0);
});
