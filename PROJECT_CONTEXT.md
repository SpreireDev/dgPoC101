# PROJECT_CONTEXT.md — Godot Roguelike Deckbuilder (Vertical Slice)

## High-level architecture
- **Main scene**: `Scenes/main.tscn` — 3D scene containing player capsule (group "player") and enemy cube (group "enemy").
- **UI overlay**: `Scenes/UI/DebugUI.tscn` — debug panel with live state display and control buttons.
- **Autoloads**:
  - `BattleManager` — central real-time battle loop, timers, and state.
  - `CardDatabase` — loads and serves CardData from JSON.
- **Node hierarchy**: Main (3D root) → player/enemy nodes + CanvasLayer (DebugUI).

## Key scripts + one-sentence purpose
- `BattleManager.gd`: Manages the complete real-time card battle loop (draw timer, mana regen, hand/deck/discard, play logic, attack animation).
- `CardDatabase.gd`: Loads all CardData from `Resources/cards.json` into a runtime array and provides lookup.
- `CardData.gd`: Minimal data class holding card properties (name, damage, etc.).
- `Enemy.gd`: Tracks enemy HP and exposes `take_damage()` / `reset_hp()` methods.
- `DebugUI.gd`: Binds to BattleManager signals and drives the debug overlay + buttons.

## Current features / state / known issues
**Features (battle loop complete)**:
- Independent 3s draw timer + 2s mana regen timer.
- Hand size 5, starting hand 3, mana max 3 (starts at 1).
- Play card at index → spend 1 mana → tween attack → deal damage.
- Auto-shuffle when deck empties; timer pauses on full hand.
- Full debug UI with live timers, HP, counts, last card, and buttons (Play 0, Kill, Respawn).

**State**: Prototype battle loop is functional and playable. GitHub repo has 2 commits (`master` branch). No Exploration or Reward modes implemented yet.

**Known issues**:
- Starting mana = 1 (spec default was 3).
- Hardcoded 1 mana cost per card.
- No reward choice UI or mode switching (`current_mode` is static "Battle").
- Enemy/player references rely on scene groups + duck-typed methods.

## Coding conventions & important decisions
- Pure GDScript, Godot 4.6+ best practices.
- `signal state_changed` emitted on every relevant change for reactive UI.
- Timers created as children in `_ready()` with code-based signal connections.
- Card data in single JSON file (faster iteration than many .tres resources).
- Debug helpers (`kill_enemy()`, `respawn_enemy()`) kept for rapid testing.
- Minimal comments — rely on clear naming and small functions.
- Godot Git Plugin included for future workflow.