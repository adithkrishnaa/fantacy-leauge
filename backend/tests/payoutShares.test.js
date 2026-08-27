const test = require('node:test');
const assert = require('node:assert/strict');
const { calculateHouseShares } = require('../utils/payoutShares');

test('splits the remainder using both configured Admin and Manager weights', () => {
  assert.deepEqual(calculateHouseShares(450, 5, 10), {
    adminShare: 150,
    managerShare: 300,
  });
});

test('allocates the entire remainder without rounding loss', () => {
  const shares = calculateHouseShares(250, 5, 15);
  assert.equal(shares.adminShare, 62.5);
  assert.equal(shares.managerShare, 187.5);
  assert.equal(shares.adminShare + shares.managerShare, 250);
});

test('rejects missing share weights when money remains', () => {
  assert.throws(() => calculateHouseShares(100, 0, 0), /configured/i);
});

test('returns zero shares when no money remains', () => {
  assert.deepEqual(calculateHouseShares(0, 0, 0), { adminShare: 0, managerShare: 0 });
});
