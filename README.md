# Mac Lid Angle & Weight Sensor

A small **macOS** utility that reads your MacBook **lid angle** from the built-in HID sensor, shows **estimated mass** from **Force Touch** trackpad pressure (demo only, not a calibrated scale), and can play **creak** or **synthesized theremin** audio that follows lid motion. Master output level is adjustable in the app.

This fork is maintained independently. The original idea and early implementation came from [Sam Henri Gold](https://github.com/samhenrigold)’s public project; this codebase, UI, weight readout, and packaging are evolved here under the same [MIT License](LICENSE) (see file for copyright and terms).

---

## Supported platform

| | |
| --- | --- |
| **OS** | **macOS 11.5 (Big Sur) or later** — AppKit, **Apple Silicon or Intel** |
| **Not supported** | iOS, iPadOS, tvOS, visionOS, Windows, Linux |

The Xcode target sets `MACOSX_DEPLOYMENT_TARGET` to **11.5** for the app. You need a Mac that can build and run a standard macOS `.app` (Xcode or command-line tools).

---

## Hardware: what actually works

### Lid angle

The app looks for a specific **IOHID** match (Apple vendor, a fixed product ID, sensor usage page **0x0020**, orientation usage **0x008A**). Implementation: `LidAngleSensor.m` (`findLidAngleSensor`).

- **Works on:** MacBook **Pro** models (and potentially other Apple notebooks) that expose **that** HID device. It has been **validated on Apple Silicon MacBook Pro** with the sensor present.
- **Typically does not work on:** iMac, Mac mini, Mac Studio, Mac Pro, and most MacBook **Air** configurations — they usually **do not** ship this lid sensor HID surface (or use different IDs).

If the sensor is missing, the app shows that no lid sensor was found. If your machine should have a sensor but nothing matches, the HID product ID or report layout may differ from this build; extending the matcher in `LidAngleSensor.m` is the right place to adapt it.

### “Weight” (trackpad)

Mass is derived from **NSEvent** trackpad **pressure** while the app is frontmost (`WeightSensor.m`). You need a **Force Touch** trackpad (recent MacBook trackpads). This is a **rough relative estimate**, not a legal-for-trade scale.

### Angle value

The 16-bit HID field is treated as **degrees** on hardware used for testing (`LidAngleSensor.m`). If a future Mac reports a different unit, adjust the conversion there.

---

## Features (current codebase)

- Live **lid angle** (degrees) and **angular rate** (from the audio engine) when audio is available  
- **Status** hint (closed / ajar / open / wide open) based on angle bands  
- **Mass** display in **g**, **kg**, **lb**, or **oz** when Force Touch events are available  
- **Audio:** creak vs. “alien” theremin segment, play/stop, **master volume** slider (persisted in `UserDefaults`)

---

## Build and run

**Prerequisites:** macOS with **Xcode** or **Xcode Command Line Tools** (`xcode-select --install`).

```bash
git clone https://github.com/Dev-Muhammad-Junaid/mac-lid-angle-and-weight-sensor.git
cd mac-lid-angle-and-weight-sensor
```

### Debug build (example, no code signing)

```bash
xcodebuild \
  -project "LidAngleSensor.xcodeproj" \
  -scheme "LidAngleSensor" \
  -configuration Debug \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" DEVELOPMENT_TEAM="" \
  -arch arm64
```

On **Intel** Macs, use `-arch x86_64` or omit `-arch`. Lid-angle hardware is still limited to supported notebooks as above.

### Run

```bash
open build/Build/Products/Debug/LidAngleSensor.app
```

For **Release**, change `Debug` to `Release` in the path. Adjust signing in Xcode if you distribute a signed build.

---

## Contributing

Issues and pull requests are welcome on this repository. Please mention your **Mac model**, **macOS version**, and whether **HID** or **pressure** readouts fail when reporting bugs.
