## Hud
# Minimal placeholder HUD for economic decisions.
# Displays current money prominently and can show a transient price-band line.
class_name Hud
extends CanvasLayer

@onready var money_label: Label = $MoneyLabel
@onready var price_band_label: Label = $PriceBandLabel

func _ready() -> void:
	set_money(0)
	price_band_label.text = ""

## Updates the money display with the current balance.
func set_money(amount: int) -> void:
	money_label.text = "Money: %d" % amount

## Shows a transient price-band confirmation line.
## Call clear_price_band() or pass an empty string to hide it.
func show_price_band(text: String) -> void:
	price_band_label.text = text

## Hides the price-band line.
func clear_price_band() -> void:
	price_band_label.text = ""
