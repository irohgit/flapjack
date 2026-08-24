# Flapjack Shop UI

This folder contains the Shop presentation layer only. It does not spend coins,
grant weapons, or modify player inventory.

## Preview

Open `shop_preview.tscn` and run the current scene (F6). The preview simulates
coin spending locally so all card and button states can be reviewed safely.

## Runtime entry point

`GameUI` now contains a hidden `ShopMenu` instance. A future gameplay trigger
can open it through:

```gdscript
$GameUI.open_shop(player.coin_count)
```

Connect `ShopMenu.purchase_requested(item_id, price, category)` to the gameplay
shop system when authoritative item resources, prices, and purchase rules are
ready. The current catalogue prices are explicitly UI placeholders.

## Asset organisation

All extracted textures live under `Assets/UI/Shop/` and are grouped into:

- `Panels`, `Cards`, and `Buttons`
- `Items/Weapons`, `Items/Augments`, and `Items/Potions`
- `Icons/Status`, `Icons/Stats`, and `Icons/Rarity`
- `Decorations`
- `_Source` for the original atlas and cleanup script
