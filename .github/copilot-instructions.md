# 15 Puzzle Solver Project Instructions

## Project Overview
Flutter app implementing a sliding 15-puzzle with an IDA* (Iterative Deepening A*) solver. Single-file architecture (`lib/main.dart`) containing UI and algorithm code.

## Architecture

### Key Components
- **PuzzlePage**: Main stateful widget managing puzzle state, user interactions, and solver animation
- **IDA* Solver** (`solve15PuzzleIDAStar`): Runs in isolate via `compute()` to keep UI responsive
- **Solver Algorithm**: Uses Manhattan distance heuristic with incremental updates for efficiency
- **Animation System**: Step-by-step playback of solution moves with adjustable speed (100-1000ms/step)

### State Management
- `_tiles`: List<int> representing puzzle (0 = blank, 1-15 = tiles)
- `_solving`: bool flag prevents user interaction during solve/animation
- `_stopRequested`: bool for graceful animation cancellation
- `_stepDelay`: Duration controlling animation speed (default 500ms)

## Critical Patterns

### Naming Conventions
- **Constants**: Use lowerCamelCase (e.g., `_found`, `_inf`), NOT UPPER_CASE
- Package name is `fifteen_puzzle_self` (Dart doesn't allow names starting with digits)

### Puzzle Generation
- Shuffle via random valid moves from goal state (guarantees solvability)
- Never manually construct arbitrary positions without solvability check
- Use `isSolvable15()` before attempting to solve unknown configurations

### UI Sizing
- Board size calculated as `min(width, height) * 0.45` to prevent overflow
- Tested on various screen sizes; avoid increasing multiplier above 0.5

### Testing
- Test file uses `FifteenPuzzleApp` (not `MyApp` from template)
- Keep tests focused on widget loading and basic UI presence

## Development Workflow

### Running the App
```bash
flutter run
```

### Common Issues
- **Overflow errors**: Board too large - adjust multiplier in `_PuzzlePageState.build()`
- **Slow animation**: Increase `_stepDelay` (current range: 100-1000ms)
- **Lint errors**: Ensure constants use lowerCamelCase, remove unused imports

### Performance Notes
- IDA* runs in isolate (via `compute()`) - never block main thread with heavy computation
- Solution finding can take seconds for difficult positions (maxDepth=200)
- Animation automatically stops if widget unmounted (`if (!mounted) return`)

## Algorithm Details

### IDA* Implementation
- Entry point: `_solveIDAEntry()` (required for `compute()` top-level function)
- Returns `List<int>?` of tile numbers to move (not directions)
- Uses incremental Manhattan distance updates (only moved tile changes)
- Direction pruning prevents immediate move reversal

### Solvability Check
- Even width (4×4): `blankEven == invOdd` (equality, not XOR)
- Pre-check in `_solveAndAnimate()` provides better error messages
- Shuffle always generates solvable positions

## File Structure
```
lib/main.dart           # Single file with all code (UI + algorithm)
test/widget_test.dart   # Basic widget loading test
```

## Common Modifications

### Changing Animation Speed
Adjust slider range in `_SpeedControl.build()`:
```dart
value: value.clamp(100, 1000),  // min, max in milliseconds
min: 100,
max: 1000,
divisions: 45,  // number of discrete steps
```

### Adjusting Puzzle Difficulty
Modify shuffle count in UI buttons:
```dart
FilledButton.icon(
  onPressed: _solving ? null : () => _shuffle(120),  // move count
  ...
)
```
