const test = require('node:test');
const assert = require('node:assert/strict');
const { assertTransactionReadAccess } = require('../utils/transactionAccess');

test('allows a user to read their own transactions', () => {
  assert.doesNotThrow(() => assertTransactionReadAccess({ _id: 'user-1', userType: 'Member' }, 'user-1'));
});

test('allows Admin to read another users transactions', () => {
  assert.doesNotThrow(() => assertTransactionReadAccess({ _id: 'admin-1', userType: 'Admin' }, 'user-1'));
});

test('denies a user reading another users transactions', () => {
  assert.throws(
    () => assertTransactionReadAccess({ _id: 'user-1', userType: 'Member' }, 'user-2'),
    (error) => error.statusCode === 403 && /own transaction/i.test(error.message),
  );
});
