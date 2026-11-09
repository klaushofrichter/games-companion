# games-companion

An iPhone app that lies flat on the [Game Table](https://games.skylar.technology) next to the board, as a side
display. It is optional: the board works the same without it; when the phone is there, it adds to the table.

Runs on an iPhone X (iOS 16), portrait, never dims by itself. Three pages, swiped left and right:

| Page | What it shows |
| --- | --- |
| **Games** | The table's games, one after another (every 9 s; tap to move on, tap the left edge to go back). Each builds up in steps over a glowing backdrop in its colour: the board screenshot or the game's art (slowly zooming), players, its name and what your phone does in it. One game crossfades into the next |
| **Table** | Now playing (not connected to the table yet, so "No game running"), the time, a game timer that survives restarts, and the weather where the phone is (Open-Meteo, no key) |
| **Screensaver** | Muted, slow light that doesn't distract from the board: an aurora, or waves over a colour that changes through the hours. A tap switches |

Every 5 minutes the front camera (facing the ceiling) measures the room's light for about a second; the screen
brightness follows it, and in a dark room the app dims itself further. No pictures are taken or kept.

After an hour without a touch the energy saver takes over: only the time, dim on black, moving a little every minute
so it doesn't burn into the OLED screen. Screen brightness drops to its lowest and the camera stops sampling. The next
touch brings the pages back. The launch argument `idle=<seconds>` shortens the hour for testing.

The app icon is drawn by `tools/make-icon.swift`:
`swift tools/make-icon.swift GameCompanion/Assets.xcassets/AppIcon.appiconset/icon.png`.

The game list is bundled: the platform's built-in games and the five from extra-games are in
`GameCompanion/Game.swift`, with the board screenshots games.skylar.technology publishes in `GameCompanion/Games/`.

Games that must not be in a public repository go in `GameCompanion/Private/` (git-ignored): `house-games.json` and
their pictures. The app includes them when the folder is there at build time and mixes them in with the others. Each
entry has `id`, `name`, `players`, `tagline`, `description`, `phone`, `color` (`[r, g, b]`, 0–1) and `art`: `hexTiles`
or `imageRow` with `images` (file names in the folder), or `marbleTrack` with a `title`.

## Deploying

```
./deploy.sh            # build, install and launch on the one reachable iPhone (USB or Wi-Fi)
./deploy.sh page=table # launch arguments go to the app; page=table or page=screensaver opens on that page
./deploy.sh --check    # unsigned build only
```

The version is `YYYY.MM.DD.N`, set at deploy time and tagged `v…` locally. The iPhone must be registered with the
team on developer.apple.com (Xcode 27 can't register an iOS 16 device itself) and have Developer Mode on.

## Licence

MIT, see [LICENSE](LICENSE).

## Not yet

Talking to the table: the board's current game, players, scores and turn, volume, a lobby view. The board must never
wait for the companion.
