# Zombie Tower Defense 3D — Unity Port

This is a separate Unity prototype alongside the original Godot project. The Godot version is intentionally preserved.

## Open in Unity
1. Install Unity Hub and a Unity 2022.3 LTS or newer supported editor, including Android Build Support (SDK/NDK + OpenJDK).
2. Create a new 3D Core project, then copy `Assets/Scripts/GameBootstrap.cs` into its `Assets/Scripts/` folder.
3. Press Play. The runtime bootstrap generates the arena, forest, UI, turrets and enemies automatically.
4. For Android, switch Build Settings to Android, set portrait/landscape as preferred, enable ARM64, then build an APK.

## Prototype status
- Procedural 3D arena and dark forest perimeter
- Main menu, restart, turret selection, touch/mouse placement
- Wave and episode counters, basic enemies and turret targeting
- No external art assets required

This is an initial port prototype, not yet a verified Android APK. Test in the Unity Editor first; balance, upgrade visuals, save/load, audio, touch UI layout and device profiling remain follow-up work.