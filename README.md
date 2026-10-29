# Wakey

A macOS menu bar app and widget that turns system sleep off and on with one click, so long-running agents keep going, even with the lid closed.

Wakey uses `pmset -a disablesleep 1|0` through a small root helper, so it also stops lid-close sleep. Sleep comes back on automatically when you quit Wakey, when it crashes, after a reboot, when a timer ends, or when the battery drops below 20%.

## Requirements

- macOS 14 Sonoma or later
- Xcode 15 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- A free Apple ID added in Xcode (Settings > Accounts)

## Build and run

1. Find your team ID: in Xcode, open Settings > Accounts, select your Apple ID, and note the team ID of your "Personal Team" (10 characters). You can also find it in Keychain Access, as the "Organizational Unit" of your "Apple Development" certificate.
2. Generate the Xcode project:
   ```sh
   WAKEY_TEAM_ID=XXXXXXXXXX xcodegen
   ```
3. Open `Wakey.xcodeproj` and run the **Wakey** scheme.
4. Click the eye in the menu bar, choose **Set up Wakey…**, and turn Wakey on in System Settings > General > Login Items.
5. Add the widget: right-click the desktop > Edit Widgets > Wakey.

If setup fails when running from Xcode, copy `Wakey.app` to `/Applications` and run it from there.

## Project layout

| Folder | Target | What it does |
| --- | --- | --- |
| `App/` | Wakey | Menu bar UI, timer presets, setup and removal of the helper |
| `Widget/` | WakeyWidget | Small widget with a toggle button |
| `Helper/` | WakeyHelper | Root launchd daemon: runs `pmset`, owns the timer, enforces the safety rules |
| `LaunchDaemons/` | (in Wakey.app) | launchd plist for the helper |
| `Shared/` | several | XPC protocol, XPC client, `pmset` and battery helpers |

## Checking it works

```sh
pmset -g | grep SleepDisabled   # 1 = Wakey is keeping the Mac awake
```

The helper logs to the system log; filter on `Wakey helper` in Console.app.
