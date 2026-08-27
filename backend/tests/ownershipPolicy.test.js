const test = require('node:test');
const assert = require('node:assert/strict');
const {
  assertMatchOwnership,
  assertMemberOwnership,
} = require('../utils/ownershipPolicy');

test('allows an Admin to manage any match', () => {
  assert.doesNotThrow(() => assertMatchOwnership(
    { _id: 'admin-1', userType: 'Admin' },
    { id: 'match-1', manager: 'manager-2' },
  ));
});

test('allows a Manager to manage their own match', () => {
  assert.doesNotThrow(() => assertMatchOwnership(
    { _id: 'manager-1', userType: 'Manager' },
    { id: 'match-1', manager: 'manager-1' },
  ));
});

test('denies a Manager access to another Managers match', () => {
  assert.throws(
    () => assertMatchOwnership(
      { _id: 'manager-1', userType: 'Manager' },
      { id: 'match-1', manager: 'manager-2' },
    ),
    (error) => error.statusCode === 403 && /another manager/i.test(error.message),
  );
});

test('allows a Manager to manage a Member in their club', () => {
  assert.doesNotThrow(() => assertMemberOwnership(
    { _id: 'manager-1', userType: 'Manager' },
    { id: 'club-1', user: 'manager-1' },
    { id: 'member-1', memberOf: 'club-1', userType: 'Member' },
  ));
});

test('denies a Manager access to a Member outside their club', () => {
  assert.throws(
    () => assertMemberOwnership(
      { _id: 'manager-1', userType: 'Manager' },
      { id: 'club-1', user: 'manager-1' },
      { id: 'member-1', memberOf: 'club-2', userType: 'Member' },
    ),
    (error) => error.statusCode === 403 && /another club/i.test(error.message),
  );
});

test('denies wallet management for a non-Member account', () => {
  assert.throws(
    () => assertMemberOwnership(
      { _id: 'manager-1', userType: 'Manager' },
      { id: 'club-1', user: 'manager-1' },
      { id: 'admin-1', memberOf: null, userType: 'Admin' },
    ),
    (error) => error.statusCode === 403 && /member account/i.test(error.message),
  );
});
