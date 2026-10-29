# Zombie Tower Defense 3D — Unity Port

This is the Unity runtime prototype alongside the preserved Godot project.

## Open in Unity
1. Install Unity Hub and Unity **2022.3 LTS** with Android Build Support (SDK/NDK + OpenJDK).
2. Create a **3D Core** project, then copy `Assets/Scripts/GameBootstrap.cs` from this folder into the new project's `Assets/Scripts/` folder.
3. Press **Play**. The bootstrap generates the arena, route, perimeter forest, UI, turrets and enemies at runtime.
4. For Android, switch Build Settings to Android, enable ARM64 and build a debug APK.

## Prototype systems currently implemented
- Procedural 3D arena and zombie route; no external map downloads or art assets required.
- Brighter ambient and directional lighting, plus a solid camera background to reduce the near-black scene issue.
- Five turret types: Sentry, Heavy Cannon, Gatling, Rocket and Tesla.
- Tap an empty tile to place a turret; tap an existing turret to upgrade it through **Level 5**.
- Upgrade levels visibly change turret primitive/size and increase damage and range.
- Episode and wave counters, escalating enemy health/speed, rewards and basic base health.
- Main menu, continue/restart, graphics presets with 30/45/60 FPS caps, and master-volume slider.
- Mouse input in the Editor and basic touch input path for Android.

## Current limitations — not yet verified as a finished game
- This is still a single fixed arena, not an open-world map streamer. The map is procedural and small, so it does not download a full world.
- Audio slider controls Unity's master audio level, but sound effects/music have not been authored yet.
- Save/load, polished touch controls, attack projectiles/animations, balancing and device performance profiling remain unfinished.
- **No Unity Android APK has been built or tested yet.** The existing APK workflow exports the separate Godot project; it does not build this Unity port.
- Please open in Unity 2022.3 LTS and test compile/play mode before treating the port as release-ready.
