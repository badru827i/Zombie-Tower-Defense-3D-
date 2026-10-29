# Zombie Tower Defense 3D

**Engine:** Godot 4.x · **Target:** Android · **Mode:** Offline-first

## Current milestone: playable prototype systems

- Top-down 3D arena with a visible zombie route and build grid.
- Mouse and Android screen-tap placement controls.
- Tap an existing turret to upgrade it through Level 5, with upgrade costs.
- Five turret types: Sentry, Heavy Cannon, Gatling, Rocket, Tesla.
- Five enemy types: Walker, Runner, Armored, Toxic, Mutant Boss.
- Automatic turret targeting and visible Level 1–5 turret evolution with scaling damage.
- 100-episode campaign progression with five waves per episode and a final boss encounter.
- Main menu, Play/Continue, Restart Run, pause/menu access, and local campaign save/load.
- Graphics quality presets (Low/Medium/High) with distance culling and frame-rate caps.
- Master, SFX and ambient music volume controls saved locally; generated ambient drone and wave-start cue.
- Procedural low-poly forest border, fog, dirt route and blood marks; no map downloads required.

## Campaign plan

The campaign now advances through five waves per episode, Episode 1–100, and ends after the Episode 100 boss wave. Difficulty rises by episode. This remains a prototype: visuals use procedural meshes and needs real-device playtesting and balance work.

## Run locally

1. Install Godot 4.x.
2. Import `project.godot`.
3. Press **F5** to run the project.

## Android APK

Android export needs the Godot Android export templates plus Android SDK/JDK setup. The APK is not confirmed ready until an export succeeds and the resulting build is tested on a real Android device. GitHub Actions performs a headless Godot import/parse check; check the latest Actions run for validation status.

## Next development tasks

- Add clearer turret selection/upgrade feedback and visual attack effects.
- Improve zombie path movement, attack effects, and hit feedback.
- Load weapon/enemy balance from JSON.
- Implement robust save/load and campaign completion handling.
- Add automated project checks and Android export workflow.
- Test touch input, performance, and APK installation on Android.
