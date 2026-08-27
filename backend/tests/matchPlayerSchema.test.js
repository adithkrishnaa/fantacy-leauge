const test = require('node:test');
const assert = require('node:assert/strict');
const { Prisma } = require('@prisma/client');

test('Match exposes both player JSON fields', () => {
  const match = Prisma.dmmf.datamodel.models.find((model) => model.name === 'Match');
  const fields = new Map(match.fields.map((field) => [field.name, field]));

  assert.equal(fields.get('Team1Players')?.type, 'Json');
  assert.equal(fields.get('Team2Players')?.type, 'Json');
});
