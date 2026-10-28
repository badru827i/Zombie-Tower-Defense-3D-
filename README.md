# Zombie Tower Defense 3D

**Engine:** Godot 4.x · **Target:** Android · **Mode:** Offline-first

## Current milestone: prototype foundation

- Top-down 3D arena with a visible zombie route and build grid.
- Five turret types: Sentry, Heavy Cannon, Gatling, Rocket, Tesla.
- Five enemy types: Walker, Runner, Armored, Toxic, Mutant Boss.
- Automatic turret targeting and basic wave/episode progression.
- Local save-file hook.

## Campaign plan

The target is 100 episodes with rising difficulty, special encounters, and a final boss in Episode 100. The campaign is being developed in stages; this repository is not yet a finished game.

## Run locally

1. Install Godot 4.x.
2. Import `project.godot`.
3. Press **F5** to run the project.

## Android APK

Android export needs the Godot Android export templates plus Android SDK/JDK setup. The APK is not ready until an export succeeds and the resulting build is tested on a real Android device. CI/export setup is a follow-up milestone.

## Next development tasks

- Add turret selection/upgrade interaction (maximum Level 5).
- Improve zombie path movement, attack effects, and hit feedback.
- Load weapon/enemy balance from JSON.
- Implement robust save/load and campaign completion handling.
- Add automated project checks and Android export workflow.
- Test touch input, performance, and APK installation on Android.
