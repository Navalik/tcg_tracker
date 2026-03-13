# Game Registry

`GameRegistry` is the central source of truth for game-level runtime configuration.

It owns:
- canonical `TcgGameId`
- runtime `TcgGame` bindings for enabled games
- `AppSettings` bindings for persisted selection
- display name and database filename
- purchase requirements
- per-game `GameCapabilities`
- attached provider bundle

Current enabled runtime games:
- `mtg`
- `pokemon`

Current placeholder games:
- `one_piece`
- `yugioh`
- `lorcana`

Design rules:
- UI and services should ask the registry for capabilities and metadata instead of branching on `mtg/pokemon` when possible.
- Placeholder games can exist in the registry without being exposed at runtime.
- `TcgEnvironmentController` is responsible for active selection, but configuration data comes from `GameRegistry`.

Transition note:
- Existing runtime enums still expose only `TcgGame.mtg` and `TcgGame.pokemon`.
- Future onboarding should add new runtime entries only when the app can actually select and operate that game.
