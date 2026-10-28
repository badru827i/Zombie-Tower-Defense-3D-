# Prototype test checklist

Run these checks in Godot before calling the prototype stable.

- [ ] Project opens in Godot 4.x without parse errors.
- [ ] Arena and path render with the camera framing the whole board.
- [ ] Mouse click and Android screen tap can place a turret.
- [ ] Turrets cannot be placed on path tiles or occupied tiles.
- [ ] Each of the five turret types can be selected and placed.
- [ ] Turrets automatically target enemies inside range.
- [ ] Tapping an existing turret upgrades it up to Level 5.
- [ ] Upgrade cost is deducted and insufficient cash is handled.
- [ ] Waves advance only after all spawned enemies are defeated or reach the base.
- [ ] Save button writes a local save file.
- [ ] Test a long wave with many enemies for frame rate and crashes.
- [ ] Export and install an Android APK on a physical device.

Note: the current CI workflow validates/imports the Godot project. It does not yet export an APK.
