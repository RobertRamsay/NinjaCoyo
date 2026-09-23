# Purchases

Existing purchase support: outfit passes, dog coat passes, and permanent 2x Scroll-Coins. All pass IDs currently remain 0, so these purchases are not live. Some cosmetics can also be earned through upgrades.

Super Gold Sword is a permanent pass in Dressing House > Boosts. It automatically upgrades the owner's katana, includes the base katana unlock, and one-hits their enemies within the normal sword range. Cooldown and chest damage remain unchanged. Ownership is loaded from Roblox on joining and granted immediately by the server after a successful purchase. It is restored after respawning. No consumable developer products or receipt processing are used.

## Activate the sword

1. Open the correct public NinjaCayo experience in Creator Dashboard, then Monetization > Passes.
2. Create a Super Gold Sword pass, set the Robux price and enable sales.
3. Put its pass ID in Config.Wardrobe.GoldSwordPassId in src/ReplicatedStorage/NinjaCoyoConfig.luau.
4. Sync and publish. The shop reads the price from Roblox; it is not hard-coded.
5. Verify a non-owner, canceled purchase, successful purchase, rejoin and respawn in Roblox. The automated suite mocks MarketplaceService and cannot validate a real purchase.

StudioOwnsEverything applies to cosmetics only and never grants the paid sword. Until a real pass ID is configured, the sword card says SOON and does not prompt a purchase.

Official reference: https://create.roblox.com/docs/production/monetization/passes
