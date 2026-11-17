---
name: install-iphone
description: Install or update SuperPooperApp on the user's iPhone. Use when the user asks to install the app/ipa on the iPhone, update the app on the phone, "поставь/установи на айфон", "обнови приложение на айфоне" or similar.
---

# Install SuperPooperApp on the iPhone

Everything is done by one script, also runnable without Claude (Automator app):

```bash
scripts/install-iphone.sh
```

Run it from the repo root (`/Users/chumbulev/podkapotie/super-pooper-app`, GitHub `ismylvdya/super-pooper-app`) in the background or with a long timeout (the build takes minutes). What it does, in order:

1. **Sync `main` with GitHub.** Local ahead → `git push`; GitHub ahead → `git pull --ff-only`; both ahead → stops (resolve with the user, never force). Uncommitted edits are only reported.
2. **iOS 18 → iOS 26.** If `Config/Shared.xcconfig` still has `IPHONEOS_DEPLOYMENT_TARGET[sdk=iphone*18*]`, removes it with its comment (docs/IOS26-BUILD.md, step 4), commits only that file and pushes. Needs Xcode 26.
3. **iPhone.** If `roamrun` is installed, first checks the RoamRun bridge to the iPhone (the first device in `roamrun devices`, or `SP_IPHONE`); when the iPhone is away (another network, over Tailscale) and the bridge is down, raises it with `roamrun up -d` and waits up to 60 s, else stops. Then finds the paired iPhone with `devicectl` (another one: `SP_IPHONE="name"`). If it does not answer (Wi-Fi tunnel down), opens Xcode in the background and retries for a minute.
4. **Build and install.** Removes this app's cached provisioning profiles first (Xcode would reuse them, so the signature would keep its old expiry; without them the build fetches new ones valid 7 days from now), then a Release build with `-allowProvisioningUpdates`, installed over the old app with `devicectl` (data stays).

## If it stops

- *разошлись* — local and GitHub both have new commits: show the user both lists (`git log main..origin/main`, `git log origin/main..main`) and ask how to merge.
- *pull не прошёл* — uncommitted edits conflict with GitHub: show `git status`, ask the user.
- *мост … не поднялся* — the user says the iPhone is at home on the Mac's Wi-Fi, run `SP_DIRECT=1 scripts/install-iphone.sh` (skips the bridge, plain Wi-Fi). Otherwise: the iPhone is away: ask the user to unlock it, join any Wi-Fi with internet (cellular alone does not work) and turn Tailscale on; run `roamrun doctor` for the broken link; then run again.
- *айфон не ответил* — ask the user to unlock the iPhone, be on the same Wi-Fi as the Mac, or plug in a cable; then run again.
- *build error* — fix it like any build failure (rules from CLAUDE.md), then run again.

Keep the skill and the script in sync: the script is the source of truth, change it first.
