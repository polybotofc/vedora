// The sales feature (AssetsService.StartSale/EndSale/DecrementSaleUnits and the
// catalog queries) reads and writes is_on_sale and the sale_* snapshot columns
// on the asset table, but no migration ever created them. Any catalog request
// that selects asset.is_on_sale then fails with:
//   42703: column asset.is_on_sale does not exist
const saleColumns = [
    'is_on_sale',
    'sale_units_total',
    'sale_units_remaining',
    'sale_price_robux',
    'sale_price_tix',
    'sale_pre_for_sale',
    'sale_pre_robux',
    'sale_pre_tix',
    'sale_started_at',
];

exports.up = async function (knex) {
    await knex.schema.alterTable('asset', (t) => {
        t.boolean('is_on_sale').notNullable().defaultTo(false);
        // Snapshot of the pre-sale state, restored by EndSale.
        t.boolean('sale_pre_for_sale').nullable().defaultTo(null);
        t.bigInteger('sale_pre_robux').nullable().defaultTo(null);
        t.bigInteger('sale_pre_tix').nullable().defaultTo(null);
        // Discounted price while the sale is active.
        t.bigInteger('sale_price_robux').nullable().defaultTo(null);
        t.bigInteger('sale_price_tix').nullable().defaultTo(null);
        // Discounted stock; sale ends when sale_units_remaining hits zero.
        t.bigInteger('sale_units_total').nullable().defaultTo(null);
        t.bigInteger('sale_units_remaining').nullable().defaultTo(null);
        t.dateTime('sale_started_at').nullable().defaultTo(null);
    });
};

exports.down = async function (knex) {
    await knex.schema.alterTable('asset', (t) => {
        for (const column of saleColumns) {
            t.dropColumn(column);
        }
    });
};
