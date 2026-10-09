# GPS Checker

A native SwiftUI app for iPhone and iPad: a GNSS diagnostics screen, map, compass, sun and moon times and waypoints.

## Screens

Receiver-style layout: a row of buttons on top, the current page in the middle, and page tiles at the bottom
(each a live miniature: fix state, signal bars, sky plot, clock, map).

- **Dashboard**: speedometer (km/h, mph or knots), compass with a needle that points north as the phone turns
  (T/M for true or magnetic), and an altimeter with hundreds and thousands hands and a digital counter.
- **Signal**: GNSS status (No Fix / 2D / 3D / Fix Lost), accuracy in big seven-segment digits, update count and
  rate, one bar per recent fix graded red → green by its accuracy, and an average-accuracy quality bar.
- **Sky**: polar plot turned with the phone showing the sun, the moon, the target waypoint and the direction of
  travel, with sun and moon elevation, magnetic declination and time to first fix.
- **Time**: UTC and local date and time, sunrise and sunset in LCD digits, the moon's current phase, and a 24-hour
  dial shading day, twilight and night with a hand for now.
- **Map**: Apple Maps with your accuracy circle, waypoints and a line to the target.

Top buttons: **night mode** (red display for dark adaptation), **waypoints** (save, type, rename, share, navigate),
**navigate** (compass card with target distance and bearing), **share** position, and **⋯** for the detailed data
list, full sun and moon times, Restart GPS and Settings.

Settings: coordinate format (decimal degrees, degrees-minutes, degrees-minutes-seconds, UTM, MGRS), units (metric,
imperial, nautical), north reference, and keep the screen on.

CI renders each page with sample data on every push; see the `ci-snapshots` branch.

### What iOS cannot do

Apple gives apps no access to individual satellites: there is no list of satellites, constellation, signal-to-noise
ratio, elevation/azimuth, "used in fix" flags or raw GNSS measurements. A satellite signal chart or sky view is
therefore impossible on iOS. In their place the Signal screen grades each fix by the receiver's accuracy estimate, and the Sky screen plots the
sun, moon and target instead of satellites.
There is no way to clear assisted-GPS data either; **Restart** is the closest thing.

## Building

Requires Xcode 16 or newer. Open `GPSTest.xcodeproj` and run the **GPSTest** scheme. In the Simulator use
*Features › Location* to feed it a position (the compass needs a real device).

```bash
xcodebuild test -project GPSTest.xcodeproj -scheme GPSTest \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

`.github/workflows/ios.yml` builds the app and runs its unit tests (coordinate conversions checked against PROJ,
sun and moon against SunCalc's fixtures, units, waypoints) on every push.

The icon is drawn by `python3 tools/make_app_icon.py`.

## TestFlight

`.github/workflows/testflight.yml` archives the app on a GitHub macOS runner, signs it with team `KK2M84H83J`
(Xcode creates the distribution certificate and profile itself) and uploads it to App Store Connect. Run it from
*Actions › TestFlight › Run workflow*. It needs the repository secrets `ASC_KEY_ID`, `ASC_ISSUER_ID` and `ASC_KEY_P8`
(an App Store Connect API key with the App Manager role) and the app created in App Store Connect with the bundle ID
`com.stasgold.gps.tester`.
