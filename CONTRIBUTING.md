# Contributing

Thanks for helping! A few ground rules:

- **Read the spec first:** [docs/SoThirsty-Design-Spec.md](docs/SoThirsty-Design-Spec.md). It's the source of truth.
- **Open a pull request** against `main`. CI must pass (luacheck, logic tests on Lua 5.1 and LuaJIT).
- **The quiet contract** (spec 1.1) isn't negotiable: changes must never make the addon chattier than it allows.
- **Addon policy:** keep the addon free, readable (no obfuscation) and free of ads, per Blizzard's UI Add-On Development Policy.
- **Translations:** add strings to `addon/SoThirsty/Locales/`.
