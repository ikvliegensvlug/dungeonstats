# Dungeon Stats

A scoreboard after every dungeon or raid, for World of Warcraft: Forever.

When you leave a dungeon or raid, a window in Blizzard's own dialog style shows the stars of the run, each with their portrait:

- **Most damage**, with DPS
- **Most healing**
- **Most damage taken**
- **Died most**

Then the **bosses**: which you killed, which beat you and which are still to go (Bosses 3/8). The classic dungeons and raids come with their boss list; in a new WoW Forever dungeon you see the bosses you fought.

The numbers come from the game's own damage meter, so they match what the game counts. Below them the **loot**: who got which item, in two columns with pages for long lists. The best items come first; a filter in the loot header switches between green, blue or purple and better.

- **Post to party** (or raid) shares the scoreboard in group chat.
- **Older / Newer** browse your last 100 runs.
- Dying and running back does not end the run.
- Coming from ChatBanner 1.0.5? Your saved runs and loot setting are taken over.

## Commands

| Command | What it does |
| --- | --- |
| `/dstats` | The scoreboard of the dungeon you are in so far, or of the last one |
| `/dstats last` | The last finished run |
| `/dstats test` | A sample scoreboard with you and your group |
| `/dstats options` | The options (also under Options > AddOns > Dungeon Stats) |

## Good to know

- The damage meter's numbers are secret during combat, so the scoreboard opens once the fight is over.
- Healing done outside of combat is not counted by the game's meter.

## Development

`npm test` runs offline tests on a fake WoW API (not part of the add-on package).

## License

MIT
