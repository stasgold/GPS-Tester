# GPS Checker

A native SwiftUI app for iPhone and iPad: a GNSS diagnostics screen, map, compass, sun and moon times and waypoints.

## Screens

- **Status**: fix state (searching / 2D / 3D / lost), time to first fix, fix age and time, update count and rate (Hz);
  latitude and longitude in the chosen format plus MGRS; horizontal and vertical accuracy with a live two-minute chart;
  altitude above sea level and above the WGS 84 ellipsoid, geoid separation, floor; speed, course and their accuracies;
  compass heading; whether the fix is simulated or from an external accessory; Precise Location state.
  **Restart** begins a new session so time to first fix is measured again. **Share** sends the position as text with
  an Apple Maps link; long-press a coordinate to copy it.
- **Map**: Apple Maps (standard, hybrid or satellite, with 3D elevation) showing your position and its accuracy circle,
  every waypoint, and a dashed line to the waypoint you are navigating to. Save the current position as a waypoint.
- **Compass**: a rotating compass card with true or magnetic north, heading accuracy, declination and field strength;
  markers for the GPS course, the sun and the moon (dimmed below the horizon) and a big arrow towards the target
  waypoint with its distance, bearing and time at the current speed. Falls back to GPS course on devices without a
  magnetometer.
- **Time**: local time, UTC, time zone and last fix time; sunrise, sunset, solar noon, day length, civil, nautical and
  astronomical twilight, golden hour, and the sun's elevation and azimuth; moon phase, illumination, age, moonrise,
  moonset, elevation, azimuth and distance.
- **Waypoints**: save the current position or type coordinates (decimal, with optional N/S/E/W). Tap a waypoint to
  navigate to it (compass and map); swipe or long-press to rename, copy, share, open in Maps or delete. Distance and
  bearing from where you are update live.
- **Settings** (gear on every screen): coordinate format (decimal degrees, degrees-minutes, degrees-minutes-seconds,
  UTM, MGRS), units (metric, imperial, nautical), north reference, and keep the screen on.

### What iOS cannot do

Apple gives apps no access to individual satellites: there is no list of satellites, constellation, signal-to-noise
ratio, elevation/azimuth, "used in fix" flags or raw GNSS measurements. A satellite signal chart or sky view is
therefore impossible on iOS. In their place the Status screen charts the receiver's accuracy estimate over time.
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
