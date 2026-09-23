# Progression and sky treasure

Katana: 50 Scroll-Coins. Gates: Bamboo 500; Sakura 1,000; Snow 2,500; Volcano 10,000; Spirit 50,000; Sky Monastery 150,000; Celestial Summit 300,000. Existing saves retain their unlocks; there are no automatic refunds.

Eight zones now have 3–10 floating landing platforms, 16 studs wide. Required Ninja Jump levels are 0, 1, 2, 3, 5, 7, 8, 10. Rise per step is 8, 11, 15, 18, 25, 48, 55, 70 studs. These are below 80% of the theoretical combined jump height at default gravity. Real timing and mobile usability still need Studio playtesting.

Each route reserves two chest slots: blue Sky Cache (3x normal zone chest value) and purple Summit Relic (6x). Each returns no sooner than 90 seconds after opening. The player must reach the chest and have the route's jump level to damage it. Dogs cannot target these chests from below. Ordinary coin, chest and enemy rewards are unchanged for existing zones. Terrain terrace targets inside new route footprints are skipped.

Sakura (zone 3) and Spirit (zone 6) have 48x40-stud shared rest dojos, each with six seats, benches and lighting. Players can pass the invisible enemy-only exclusion volume. Enemy spawns avoid the buildings, enemies stop chasing players inside, intruding enemies are removed, and players cannot damage enemies from inside. The safe area ends at the doorway; this is not a global pause.

Verification: tests/run.cjs checks gate costs, route counts and jump headroom, geometry creation, sanctuary boundaries/collision rules, and chest cooldown/occupancy. Test live in Studio with a fresh save and an existing save; walk in/out while chased, gather with another player, complete each route at the advertised jump level, open both treasure tiers, then confirm rejoin persistence. No Roblox Studio playtest has been performed by the agent.
