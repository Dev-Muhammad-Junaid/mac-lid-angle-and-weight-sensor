# Lid Angle Sensor

Hi, I’m Sam Gold. Did you know that you have ~rights~ a lid angle sensor in your MacBook? [The ~Constitution~ human interface device utility says you do.](https://youtu.be/wqnHtGgVAUE?t=21)

This is a little utility that shows the angle from the sensor and, optionally, plays a wooden door creaking sound if you adjust it reeaaaaaal slowly. There is also a simple synthesized “theremin” mode.

## Publish your own copy (GitHub)

1. Create an empty repository on GitHub (no README required).
2. Point `origin` at it (use `set-url` if `origin` already exists), then push:

```bash
git remote remove origin   # only if you are replacing an existing remote
git remote add origin https://github.com/YOUR_USER/YOUR_REPO.git
git branch -M main
git push -u origin main
```

Use a personal access token or SSH remote if GitHub prompts for credentials.

## FAQ

**What is a lid angle sensor?**

Despite what the name would have you believe, it is a sensor that detects the angle of the lid.

**Which devices have a lid angle sensor?**

It was introduced with the 2019 16-inch MacBook Pro. If your laptop is newer, you probably have it.

**My laptop should have it, why doesn't it show up?**

I've only tested this on my M4 MacBook Pro and have hard-coded it to look for a specific sensor. If that doesn't work, try running [this script](https://gist.github.com/samhenrigold/42b5a92d1ee8aaf2b840be34bff28591) and report the output in [an issue](https://github.com/samhenrigold/LidAngleSensor/issues/new/choose).

**Can I use this on my iMac?**

Not yet tested. Feel free to slam your computer into your desk and make a PR with your results.

**Why?**

A lot of free time. I'm open to full-time work in NYC or remote. I'm a designer/design-engineer. https://samhenri.gold

**No I mean like why does my laptop need to know the exact angle of its lid?**

Oh. I don't know.

**Can I contribute?**

I guess.

**Why does it say it's by Lisa?**

I signed up for my developer account when I was a kid, used my mom's name, and now it's stuck that way forever and I can't change it. That's life.

**How come the audio feels kind of...weird?**

I'm bad at audio.

**Where did the sound effect come from?**

LEGO Batman 3: Beyond Gotham. But you knew that already.

**Can I turn off the sound?**

Yes, never click "Start Audio". But this energy isn't encouraged.

## Build and Run (Terminal)

You can build and launch the app without Xcode’s UI using `xcodebuild`.

### Prerequisites

- macOS with Xcode or Xcode Command Line Tools (`xcode-select --install` and maybe `xcodebuild -runFirstLaunch`)
- Optional: GitHub CLI (`gh`) — or use `git clone` instead

### Clone

Using GitHub CLI:

```bash
gh repo clone samhenrigold/LidAngleSensor
cd LidAngleSensor
```

Or with Git:

```bash
git clone https://github.com/samhenrigold/LidAngleSensor.git
cd LidAngleSensor
```

### Build (Debug)

```bash
xcodebuild \
  -project "LidAngleSensor.xcodeproj" \
  -scheme "LidAngleSensor" \
  -configuration Debug \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" DEVELOPMENT_TEAM="" \
  -arch arm64
```

Notes:
- On Apple Silicon, `-arch arm64` is correct. On Intel Macs, you can use `-arch x86_64` or omit `-arch`. Intel macs don't have the feature tho, so it won't be very useful. 
- Disabling code signing is fine for local debug builds if you are not Mr. Gold. 

### Run

```bash
open build/Build/Products/Debug/LidAngleSensor.app
```

If you built a Release configuration, adjust the path accordingly (replace `Debug` with `Release`).
