# Vendor Reagent Filter

A World of Warcraft Forever addon (interface `16001`).

It adds a **Have Materials (except vendor reagents)** checkbox to the Filter menu of the profession window. The checkbox is directly after **Have Materials**.

When the checkbox is selected, the recipe list shows only learned recipes for which you have all reagents that are not vendor reagents. Thus you can see what you can cook before you buy spices or water.

## Install

Copy the `VendorReagentFilter` folder into `World of Warcraft\_forever_\Interface\AddOns`. Then type `/reload` in game.

## Use

1. Open a profession window, for example Cooking.
2. Click **Filter**.
3. Select **Have Materials (except vendor reagents)**.
4. Keep the standard **Have Materials** checkbox clear.

## Vendor reagent list

The default list contains these cooking items:

| Item ID | Name |
| --- | --- |
| 159 | Refreshing Spring Water |
| 1179 | Ice Cold Milk |
| 2596 | Skin of Dwarven Stout |
| 2665 | Stormwind Seasoning Herbs |
| 2678 | Mild Spices |
| 2692 | Hot Spices |
| 2894 | Rhapsody Malt |
| 3713 | Soothing Spices |
| 4536 | Shiny Red Apple |
| 17194 | Holiday Spices |
| 17196 | Holiday Spirits |
| 30817 | Simple Flour |

The list is saved for each account. Change it with these commands:

- `/vrf list`
- `/vrf add <item link or ID>`
- `/vrf remove <item link or ID>`

## Limits

- The count in brackets beside a recipe does not include this filter.
- The reset button on the Filter button does not clear this checkbox.

## Test

`tests/test_filter.lua` runs the addon file against stubs of the WoW API. Run it with a Lua interpreter from the repository root:

```bash
lua tests/test_filter.lua
```

## License

MIT. See `LICENSE`.
