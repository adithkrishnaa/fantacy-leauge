const test = require('node:test');
const assert = require('node:assert/strict');

const {
  generateUniqueReferralCode,
  ensureUserReferralCode,
} = require('../utils/referralCode');

test('generates an eight-character uppercase referral code', async () => {
  const users = {
    findUnique: async () => null,
  };

  const code = await generateUniqueReferralCode(users, () => Buffer.from('a1b2c3d4', 'hex'));

  assert.equal(code, 'A1B2C3D4');
});

test('retries when a generated referral code already belongs to another user', async () => {
  const generated = [
    Buffer.from('11111111', 'hex'),
    Buffer.from('22222222', 'hex'),
  ];
  const users = {
    findUnique: async ({ where }) => where.referralCode === '11111111' ? { id: 'existing' } : null,
  };

  const code = await generateUniqueReferralCode(users, () => generated.shift());

  assert.equal(code, '22222222');
});

test('backfills a unique referral code for an existing member that has none', async () => {
  let updateInput;
  const users = {
    findUnique: async () => null,
    updateMany: async (input) => {
      updateInput = input;
      return { count: 1 };
    },
  };

  const code = await ensureUserReferralCode(
    users,
    { id: 'member-1', userType: 'Member', referralCode: null },
    () => Buffer.from('abcdef12', 'hex'),
  );

  assert.equal(code, 'ABCDEF12');
  assert.deepEqual(updateInput, {
    where: { id: 'member-1', referralCode: null },
    data: { referralCode: 'ABCDEF12' },
  });
});

test('returns the saved code when another request backfills the member first', async () => {
  const users = {
    findUnique: async (input) => {
      if (input.where.id === 'member-1') {
        return { referralCode: 'SAVED123' };
      }
      return null;
    },
    updateMany: async () => ({ count: 0 }),
  };

  const code = await ensureUserReferralCode(
    users,
    { id: 'member-1', userType: 'Member', referralCode: null },
    () => Buffer.from('abcdef12', 'hex'),
  );

  assert.equal(code, 'SAVED123');
});

test('preserves an existing referral code without writing to the database', async () => {
  let updated = false;
  const users = {
    update: async () => {
      updated = true;
    },
  };

  const code = await ensureUserReferralCode(users, {
    id: 'member-1',
    userType: 'Member',
    referralCode: 'EXIST123',
  });

  assert.equal(code, 'EXIST123');
  assert.equal(updated, false);
});
