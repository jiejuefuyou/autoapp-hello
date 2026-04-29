# CI Secrets — `autoapp-hello`

Secrets configured at **repo settings → Secrets and variables → Actions**, environment **`testflight`** (gated environment so the `beta` job won't run on PRs from forks).

## Required secrets

| Name | What it is | Where to get it |
|---|---|---|
| `ASC_KEY_ID` | App Store Connect API Key ID (10-char string, e.g. `7K8L9MNOPQ`) | App Store Connect → Users and Access → Keys → key row |
| `ASC_ISSUER_ID` | Issuer ID (UUID) at the top of the API Keys page | App Store Connect → Users and Access → Keys |
| `ASC_KEY_CONTENT` | The `.p8` private-key file, **base64-encoded** (see below) | Downloaded once when key is created — Apple does not allow re-download |
| `MATCH_PASSWORD` | Passphrase used to encrypt certs/profiles in `autoapp-certs` | Pick a strong random string the first time `fastlane match` runs |
| `MATCH_GIT_BASIC_AUTHORIZATION` | `base64(github_username:PAT)` for read access to private `autoapp-certs` | GitHub PAT with `repo` scope, base64-encode `username:token` |
| `FASTLANE_USER` | Apple ID email (`sh1990914@hotmail.com`) | — |
| `TEAM_ID` | Apple Developer Team ID (10-char) | App Store Connect → Membership |
| `ITC_TEAM_ID` | App Store Connect Team ID (numeric) | First `fastlane deliver` run prints it; or fetch via `fastlane spaceship` |

## Encoding helpers

### `.p8` to base64
```sh
base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy   # macOS
base64 -w 0 AuthKey_XXXXXXXXXX.p8           # Linux
certutil -encode AuthKey_XXXXXXXXXX.p8 tmp.b64 && type tmp.b64   # Windows (then strip BEGIN/END headers)
```

### Match git auth header
```sh
echo -n "jiejuefuyou:ghp_xxxxxxxxxxxx" | base64
```

## One-time bootstrap (run from a Mac, not CI)

After all secrets above are set, on a Mac with Xcode + fastlane:

```sh
git clone https://github.com/jiejuefuyou/autoapp-hello
cd autoapp-hello
brew install xcodegen
bundle install
export ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_KEY_CONTENT="$(base64 -i AuthKey_XXX.p8)" \
       MATCH_PASSWORD=… FASTLANE_USER=… TEAM_ID=…
bundle exec fastlane init_signing
```

This creates the appstore + development certificates and provisioning profiles, encrypts them with `MATCH_PASSWORD`, and pushes them to `autoapp-certs`. From that point on, CI can sign with `readonly: true` (no admin keys leak to runners).

## Rotation

| Secret | When to rotate |
|---|---|
| `ASC_KEY_CONTENT` | If leaked, or yearly. Revoke old key in ASC, create new. |
| `MATCH_PASSWORD` | If leaked: re-run `match nuke` then `init_signing` with new password. |
| `MATCH_GIT_BASIC_AUTHORIZATION` | If PAT expires/leaks. Mint new PAT, re-encode. |
