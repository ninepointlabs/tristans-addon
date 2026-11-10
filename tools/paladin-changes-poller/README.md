# paladin-changes-poller

WoW addons can't go online, so this small Python script (standard library only)
runs on your PC, polls the public change feeds listed in
`research/data.json → change_sources`, keeps Paladin/PvP-relevant and Forever
client/build items, and writes `Data/Changes.lua`. The addon shows those under
**What's changed** with an unread badge after the next `/reload` or login.

No logins, no API keys, no secrets. Generic User-Agent.

## Run once

```sh
python3 tools/paladin-changes-poller/poller.py -v                # writes <repo>/Data/Changes.lua
python3 tools/paladin-changes-poller/poller.py --dry-run -v      # print only, don't save state
python3 tools/paladin-changes-poller/poller.py -v \
  --output "$HOME/Games/battlenet/drive_c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/TristansAddon/Data/Changes.lua"
```

State (seen items, page-text baselines) lives in
`$XDG_STATE_HOME/tristans-addon/poller.json` (default `~/.local/state/…`).
"Page" sources (e.g. the Blizzard hotfix article that's updated in place) record
a baseline on the first run and report new Paladin/PvP-related lines after that.

## Timer (user unit, not enabled by default)

```sh
mkdir -p ~/.config/systemd/user
cp tools/paladin-changes-poller/systemd/tristans-addon-poller.{service,timer} ~/.config/systemd/user/
# edit the paths in the .service if your repo/WoW install differ
systemctl --user daemon-reload
systemctl --user start tristans-addon-poller.service     # one test run
journalctl --user -u tristans-addon-poller -n 20
systemctl --user enable --now tristans-addon-poller.timer # only when you want it scheduled
```

Note: reinstalling/updating the addon (e.g. via OmaForge) replaces
`Data/Changes.lua` with the packaged copy; the next poller run rewrites it.
Read state is kept in SavedVariables, so nothing you've read reappears.

## Tests

```sh
python3 tools/paladin-changes-poller/tests/test_poller.py -v
```
