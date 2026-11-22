# Testing

## Executed (Godot 4.4.1 headless, Linux)
16 checks in tests/run_tests.gd, all passing: settings round trip, save write, corrupt-save recovery, defaults, level unlocking, personal best, daily seed, level start, piece settling, stacking, off-platform loss.

## Not yet done
Real rendering, screenshots, touch feel, Android emulator/device, performance and FPS, memory, lifecycle on device, different screen sizes, audio (no assets).

## Known issues
- Physics tuning (piece sizes, friction, goal heights) is unverified by hand play.
- Wind force values are untested for difficulty.
- No in-game settings for individual volume sliders or reduced motion yet (settings exist in code).
