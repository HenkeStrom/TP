# &lt;TP&gt;

**A guild addon for WoW: Forever, built for the guild &lt;TP&gt;.**

&lt;TP&gt; is a small, modular guild addon. It collects tools for guild members in one window, opened from a minimap button. Each feature is a separate module that you can turn on or off. The first module is **Kill List**.

## Kill List

Tired of the same opposite-faction players camping your flight paths and quest hubs? Kill List is a shared, guild-wide list of known gankers. It warns you as soon as one of them shows up.

### Features

- **Shared with your guild.** Add a name and everyone in your guild who runs the addon gets it automatically. Players who were offline catch up the next time they log in.
- **Instant warnings.** When a listed player shows up as your target, under your mouse or as a nameplate, you get a raid-warning style alert with a sound. The alert says who it is and where you are, who listed them and why.
- **You own your entries.** You can add and remove your own names, but not anyone else's. If two people list the same player, each entry stays until its owner removes it. Entries added on your alts count as yours.
- **Reasons and history.** Add a short reason ("camps Southshore FP"). Hover over an entry to see who added it, when, and where the player was last seen.
- **Adjustable.** Choose how long to wait before the same player triggers a new warning, whether alerts make a sound, and whether they fire inside instances and battlegrounds.
- **Built for Forever names.** Players are listed by first name and surname, so only the right person triggers a warning. Only know the first name? Add just that, and everyone with that first name will trigger a warning.
- **Quick to use.** Type a name, or leave the field empty to add your current target.

> **Tip:** turn on enemy nameplates (default key: **V**). Listed players are then detected from a distance, before you ever click on them.

## Commands

| Command | What it does |
|---|---|
| `/tp` | Open the main window |
| `/tp minimap` | Show or hide the minimap button |
| `/kl` | Open the Kill List page |
| `/kl add First Last, reason` | Add a player (the comma separates the reason) |
| `/kl add` | Add your current target |
| `/kl remove <name>` | Remove your own entry |
| `/kl list` | Print the list to chat |
| `/kl test` | Show a test alert |

## Good to know

- **Guild only.** Data is synced over the guild's hidden addon channel and nothing else. Every guild that uses the addon has its own separate list, and the other faction can never see it.
- **No server.** Every member stores a copy of the list, and the copies sync whenever members are online at the same time.
- **Swedish interface.** &lt;TP&gt; is a Swedish guild, so all text in the addon is in Swedish.
- **More to come.** More guild features are planned as new modules.

---

*Made by Balkan Inferno for &lt;TP&gt;.*
