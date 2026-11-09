# game-companion

An iPhone app that lies flat on the [Game Table](https://games.skylar.technology) next to the board, as a side
display. It is optional: the board works the same without it; when the phone is there, it adds to the table.

Runs on an iPhone X (iOS 16), portrait, never dims. Two pages, swiped left and right:

| Page | What it shows |
| --- | --- |
| **Games** | The table's games, one after another (every 9 s; tap to move on, tap the left edge to go back): a board screenshot or the game's art, players, what it is and what your phone does in it |
| **Table** | Now playing (not connected to the table yet, so "No game running"), the time, a game timer that survives restarts, and the weather where the phone is (Open-Meteo, no key) |

The game list is bundled: the platform's built-in games and the five from extra-games are in
`GameCompanion/Game.swift`, with the board screenshots games.skylar.technology publishes in `GameCompanion/Games/`.

Games that must not be in a public repository go in `GameCompanion/Private/` (git-ignored): `house-games.json` and
their pictures. The app includes them when the folder is there at build time and mixes them in with the others. Each
entry has `id`, `name`, `players`, `tagline`, `description`, `phone`, `color` (`[r, g, b]`, 0–1) and `art`: `hexTiles`
or `imageRow` with `images` (file names in the folder), or `marbleTrack` with a `title`.

## Deploying

```
./deploy.sh            # build, install and launch on the one reachable iPhone (USB or Wi-Fi)
./deploy.sh page=table # launch arguments go to the app; page=table opens on the table page
./deploy.sh --check    # unsigned build only
```

The version is `YYYY.MM.DD.N`, set at deploy time and tagged `v…` locally. The iPhone must be registered with the
team on developer.apple.com (Xcode 27 can't register an iOS 16 device itself) and have Developer Mode on.

## Licence

MIT, see [LICENSE](LICENSE).

## Not yet

Talking to the table: the board's current game, players, scores and turn, volume, a lobby view. The board must never
wait for the companion.
