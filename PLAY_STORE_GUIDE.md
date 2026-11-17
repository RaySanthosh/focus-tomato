# Focus Tomato – Play Store upload guide

Everything you need to paste into Play Console. You do the clicking; nothing here needs your password shared with anyone.

## Files

| What | Where |
|---|---|
| App bundle to upload | `focus_tomato\build\app\outputs\bundle\release\app-release.aab` |
| App icon 512×512 | `store\icon-512.png` |
| Feature graphic 1024×500 | `store\feature-graphic-1024x500.png` |
| Phone screenshots (2–8) | `store\screenshots\` |
| Privacy policy page | `docs\index.html` -> https://raysanthosh.github.io/focus-tomato/docs/ |
| Upload key (BACK UP!) | `keys\` + `focus_tomato\android\key.properties` |

App ID: `com.santosh.focustomato` (permanent) · Version: 1.0.0 (versionCode 1)

---

## 1. Host the privacy policy (GitHub Pages, ~5 min)
1. Contact email is already filled in `docs\index.html`.
2. GitHub → New repository → name `focus-tomato` → Public → Create.
3. "uploading an existing file" → drag `index.html` → Commit.
4. Repo → Settings → Pages → Source: *Deploy from a branch*, Branch `main` / `/ (root)` → Save.
5. After ~1 min your URL is `https://raysanthosh.github.io/focus-tomato/docs/`. Open it to check.

## 2. Create the app in Play Console
Play Console → **Create app**
- App name: **Focus Tomato**
- Default language: English (United States) – en-US
- App or game: **App** · Free or paid: **Free**
- Tick the declarations → Create app

## 3. Store listing (Grow → Store presence → Main store listing)
**Short description (≤80):**
> Simple focus timer: 25-minute focus, short breaks, optional Do Not Disturb.

**Full description:**
> Focus Tomato is a clean, distraction-free focus timer.
>
> Work in focused sessions, then take a short break. After every few sessions, take a longer break. That's it.
>
> • Focus, short break and long break timers
> • Change any length: focus 5–90 min, breaks 1–60 min
> • Optional Do Not Disturb: silences notifications while you focus and turns them back on after
> • A notification tells you when time is up, even if the app is closed
> • Light and dark mode
>
> No account. No ads. No tracking. No internet permission. Your settings stay on your phone.

Upload icon, feature graphic, and 2+ phone screenshots from `store\`.
Category: **Productivity** · Contact email: your developer email · Privacy policy: the GitHub Pages URL.

## 4. App content (Policy → App content) – answers
| Section | Answer |
|---|---|
| Privacy policy | GitHub Pages URL |
| App access | All functionality available without special access (no login) |
| Ads | No, my app does not contain ads |
| Content rating | Questionnaire → category *Utility, Productivity, Communication, or Other* → answer **No** to everything → result: Everyone / 3+ |
| Target audience | **18 and over** (simplest; avoids the Families policy). Not designed for children. |
| News app | No |
| Data safety | Does your app collect or share any required user data types? **No**. (Nothing leaves the phone, no internet permission.) → Submit |
| Government app | No |
| Financial features | None |
| Health | None |

## 5. Closed testing (REQUIRED for personal accounts)
New personal developer accounts must run a **closed test with at least 12 testers opted in for 14 days in a row** before production access.
1. Test and release → Testing → **Closed testing** → Create track (or use *Alpha*).
2. Testers → Create email list → add **12+ Gmail addresses** (friends/family; add ~15 in case someone drops out).
3. Create new release → upload `app-release.aab` → Play App Signing: **accept** (Google keeps the real signing key; ours is only the upload key) → release name `1.0.0 (1)` → notes: "First test release."
4. Countries: add India (and any others) → Review → **Start rollout to Closed testing**.
5. Copy the **opt-in link** and send it to testers. Each must open it, tap *Become a tester*, then install from Play. Ask them to keep it installed and open it now and then.
6. After 14 days: Dashboard → **Apply for production** → answer the questions about the test → Google reviews (usually a few days).
7. Production → Create release → reuse the same bundle → roll out.

## 6. Shipping a new version later
1. In `focus_tomato\pubspec.yaml` bump `version: 1.0.0+1` → `1.0.1+2` (number after `+` must always go up).
2. `cd focus_tomato` → `flutter build appbundle --release`
3. Upload the new `.aab` in the same track → roll out.

## If you lose the upload key
Play Console → Test and release → Setup → App signing → **Request upload key reset**. Annoying but recoverable, because Play App Signing holds the real key. Still: back up `keys\` and `key.properties` somewhere private now.

## Later: hands-off uploads (optional)
After the first manual upload, a Google Cloud **service account** with Play Console access lets uploads run from the command line (fastlane / Gradle Play Publisher). The JSON key stays on your PC; you never share your password.
