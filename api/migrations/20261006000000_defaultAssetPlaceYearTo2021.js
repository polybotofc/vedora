// Vedora runs the 2021 theme only, so every existing place row must move to
// 2021 as well. Changing the column default alone would leave old rows at 2017
// and PlaceLauncher rejects any place whose year is not 2021.
exports.up = async function(knex) {
  await knex.schema.alterTable('asset_place', (table) => {
    table.bigInteger('year').notNullable().defaultTo(2021).alter();
  });
  await knex('asset_place').whereNot('year', 2021).update({ year: 2021 });
};

exports.down = function(knex) {
  return knex.schema.alterTable('asset_place', (table) => {
    table.bigInteger('year').notNullable().defaultTo(2017).alter();
  });
};
