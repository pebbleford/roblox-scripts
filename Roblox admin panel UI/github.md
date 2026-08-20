repo: pebbleford/roblox-scripts
branch: main

## Last sync
date: 2026-08-20T01:56:00Z

### Updated in this project
- Rebuilt the admin panel UI on the hub GUI architecture from the repo (dark window, title bar + accent rule, tab bar, ON/OFF toggle rows, accent sliders, log panel, notify toasts).
- Admin tab mirrors stealabrainrot-admin.lua: target picker, command pool, spam delay, base/item defense radii, quick one-shot `;` commands.
- Scripts tab lists the hub loaders and the loadstring format from CLAUDE.md.

## Screen map
| Screen | Built from |
| --- | --- |
| Admin Panel.dc.html — window chrome, toggles, sliders, log | src/translator.lua, stealabrainrot-admin.lua |
| Admin Panel.dc.html — Admin tab | stealabrainrot-admin.lua |
| Admin Panel.dc.html — Main / Movement / Visuals / Players tabs | src/uidemo_fluent.lua, src/uidemo_windui.lua, CLAUDE.md |
| Admin Panel.dc.html — Scripts tab, loadstring | CLAUDE.md, README.md |
