# &lt;TP&gt;

A modular guild addon for WoW: Forever, built for the guild &lt;TP&gt;. It collects guild tools in one window, opened from a minimap button. Each feature is a separate module that can be turned on or off.

The first module is **Kill List**: a guild-wide list of known gankers that warns you when one of them shows up. See [CURSEFORGE.md](CURSEFORGE.md) for the full feature description and the slash commands.

The addon's interface is in Swedish, since &lt;TP&gt; is a Swedish guild.

## Install

Copy the `TP` folder into your `Interface\AddOns` folder and restart the game, or type `/reload` if it was already installed.

## Repository layout

| Path | Contents |
|---|---|
| `TP/TP.toc` | Addon manifest: version and file load order |
| `TP/Core/` | Saved variables, module registry, events, guild sync transport, main window, minimap button |
| `TP/Modules/KillList/` | The Kill List module: data model, sync, detection and alerts, UI page, slash command |
| `tests/run.lua` | Off-game tests |
| `CURSEFORGE.md` | The project description used on CurseForge |

## Tests

The tests run outside the game with plain Lua 5.4. They simulate several clients in one process, with a fake clock and a fake guild channel.

```
lua tests/run.lua
```

Run this from the repository root. It prints the number of passed and failed tests and exits with a non-zero code on failure.

## Contributing

- Run the tests before you open a pull request, and add a test when you fix a bug or add logic that can be tested off-game.
- A new feature is a new folder under `TP/Modules/`. A module is a table registered with `T.RegisterModule(id, mod)`; the fields it can define are listed at the top of `TP/Core/Init.lua`. Add its files to `TP/TP.toc`.
- `TP/Modules/KillList/Data.lua` is pure Lua with no WoW API calls, so that it can be tested off-game. Keep it that way.
- Text shown to players is in Swedish. Code and comments are in English.
- Forever player names have two parts, "First Last". Use `T.UnitFullName` and `T.NormalizeName` instead of calling `UnitName` directly.
- Do not register `COMBAT_LOG_EVENT_UNFILTERED`. On Forever it triggers the "blocked from an action only available to the Blizzard UI" popup.

## Releasing

1. Update the version in `TP/TP.toc` and in `TP/Core/Init.lua` (`T.version`).
2. Run the tests.
3. Zip the `TP` folder, so that the zip contains `TP/` at its root, and upload it to CurseForge.

## License

MIT. See [LICENSE](LICENSE).
