# Expert Requirements Questions

## Q6: Should the niri rice be selectable via a new option in hosts like `rice = "niri"`?
**Default if unknown:** Yes (follows the existing pattern where hosts select their rice via an option)

## Q7: Should waybar's workspaces module use niri's IPC for dynamic workspace information?
**Default if unknown:** Yes (niri has IPC support and waybar has a niri module for proper integration)

## Q8: Should we preserve the exact same workspace numbers (1-10) or use niri's dynamic workspace model?
**Default if unknown:** No (use niri's dynamic workspace model as it's more idiomatic for niri)

## Q9: Should screenshot functionality use grim/slurp or niri's built-in screenshot UI?
**Default if unknown:** No (use niri's built-in screenshot UI for better integration)

## Q10: Should we configure niri's animation settings to match estradiol's behavior (disabled on tempest)?
**Default if unknown:** Yes (maintain the same performance optimizations per host)