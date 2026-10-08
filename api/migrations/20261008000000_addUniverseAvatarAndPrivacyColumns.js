/**
 * Games.cs reads universe.forcemorph_type, universe.privacy_type and
 * universe.cloudedit, but none of them were ever added to the schema. Signup
 * inserts a universe and then calls MultiGetUniverseInfo, whose SELECT lists
 * forcemorph_type, so a fresh row dies with:
 *   Npgsql 42703: column universe.forcemorph_type does not exist
 *
 * Defaults mirror the C# enums so freshly created universes keep the old
 * behaviour: PlayerChoice morphing (ForceMorphType.PlayerChoice = 1) and a
 * public place (PrivacyType.Public = 1).
 *
 * IF NOT EXISTS so it is safe on a fresh database and on an existing volume
 * that was patched by hand.
 */
exports.up = async (knex) => {
    await knex.raw('ALTER TABLE "universe" ADD COLUMN IF NOT EXISTS "forcemorph_type" integer NOT NULL DEFAULT 1');
    await knex.raw('ALTER TABLE "universe" ADD COLUMN IF NOT EXISTS "privacy_type" integer NOT NULL DEFAULT 1');
    await knex.raw('ALTER TABLE "universe" ADD COLUMN IF NOT EXISTS "cloudedit" boolean NOT NULL DEFAULT false');
};

exports.down = async (knex) => {
    await knex.raw('ALTER TABLE "universe" DROP COLUMN IF EXISTS "cloudedit"');
    await knex.raw('ALTER TABLE "universe" DROP COLUMN IF EXISTS "privacy_type"');
    await knex.raw('ALTER TABLE "universe" DROP COLUMN IF EXISTS "forcemorph_type"');
};
