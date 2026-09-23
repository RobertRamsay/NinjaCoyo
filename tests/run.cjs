const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const { execFileSync } = require('node:child_process');
const root = path.resolve(__dirname, '../src');
const read = file => fs.readFileSync(path.join(root, file), 'utf8').replaceAll('\r', '');
const config = read('ReplicatedStorage/NinjaCoyoConfig.luau');
const server = read('ServerScriptService/NinjaCoyoServer.server.luau');
const wardrobe = read('ServerScriptService/NinjaCoyoWardrobe.luau');
const scenery = read('ServerScriptService/NinjaCoyoScenery.luau');
const fx = read('StarterPlayerScripts/NinjaCoyoFx.client.luau');
function extract(source, name) {
 const start = source.indexOf('local function ' + name + '(');
 if (start < 0) throw Error('Missing function: ' + name);
 return source.slice(start, source.indexOf('\nend', start) + 4);
}
let upgrades = fs.readFileSync(path.join(__dirname, 'upgrade-cases.luau'), 'utf8');
upgrades = upgrades.replace('-- CONFIG_INSERT', 'local function loadConfig()\n' + config + '\nend\nlocal Config=loadConfig()');
for (const [marker, source, names] of [
 ['SAVE', server, ['createDefaultData', 'loadData']],
 ['PACK', server, ['removeCoyo', 'createCoyo', 'ensureCoyoPack']],
 ['WARDROBE', wardrobe, ['ownsPass', 'ownsItem', 'buildState', 'sendState', 'applyCoat', 'onEquip']],
 ['SPAWN', server, ['getRandomGroundInZone']],
]) upgrades = upgrades.replace('-- ' + marker + '_INSERT', names.map(n => extract(source, n)).join('\n'));
const start = scenery.indexOf('function Scenery.IsPickupClear(');
upgrades = upgrades.replace('-- CLEARANCE_INSERT', scenery.slice(start, scenery.indexOf('\nend', start) + 4));
const movement = fs.readFileSync(path.join(__dirname, 'movement-cases.luau'), 'utf8')
 .replace('-- MOVEMENT_INSERT', read('StarterPlayerScripts/NinjaCoyoMovement.client.luau'));
const swing = fs.readFileSync(path.join(__dirname, 'swing-cases.luau'), 'utf8')
 .replace('-- SWING_TUNING_INSERT', fx.slice(fx.indexOf('local SWING_WINDUP_TIME'), fx.indexOf('-- Effects tuning')))
 .replace('-- SWING_FUNCTIONS_INSERT', extract(fx, 'createSlashArc') + '\n' + extract(fx, 'playSwing') + '\n' + extract(fx, 'finishSwing') + '\n' + extract(fx, 'updateSwings'));
function publicFunction(source, name) {
 const start = source.indexOf('function ' + name + '(');
 if (start < 0) throw Error('Missing function: ' + name);
 return source.slice(start, source.indexOf('\nend', start) + 4);
}
const enemies = read('ServerScriptService/NinjaCoyoEnemies.luau');
const combat = fs.readFileSync(path.join(__dirname, 'combat-cases.luau'), 'utf8')
 .replace('-- OWNERSHIP_INSERT', extract(wardrobe, 'ownsPass') + '\n' + publicFunction(wardrobe, 'Wardrobe.OwnsGoldSword') + '\n' + extract(wardrobe, 'collectPassIds') + '\n' + extract(wardrobe, 'loadOwnedPasses'))
 .replace('-- PURCHASE_INSERT', extract(wardrobe, 'onPassPurchased'))
 .replace('-- ENEMIES_INSERT', ['Enemies.DamageEnemy', 'Enemies.HitInRange', 'Enemies.FindNearestEnemy'].map(n => publicFunction(enemies,n)).join('\n'))
 .replace('-- SWING_INSERT', extract(server, 'onKatanaSwing'));
const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'ninjacoyo-tests-'));
for (const [name, content] of [['upgrades', upgrades], ['movement', movement], ['swing', swing], ['combat', combat]]) {
 const file = path.join(temp, name + '.luau');
 fs.writeFileSync(file, content);
 execFileSync(process.env.LUAU || 'luau', [file], { stdio: 'inherit' });
 fs.unlinkSync(file);
}
fs.rmdirSync(temp);
