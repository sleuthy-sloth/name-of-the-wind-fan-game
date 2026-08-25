## Hud
# Minimal placeholder HUD for economic decisions.
# Displays current money prominently and can show a transient price-band line.
class_name Hud
extends CanvasLayer

@onready var money_label: Label = $MoneyLabel
@onready var price_band_label: Label = $PriceBandLabel

var _sfx_player: AudioStreamPlayer = null
var _last_sfx_time: float = 0.0

func _ready() -> void:
	set_money(0)
	price_band_label.text = ""
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.name = "HudSfx"
	add_child(_sfx_player)
	var sfx := AudioLibrary.stream_for("SFX_UI_TOGGLE")
	if sfx is AudioStream:
		_sfx_player.stream = sfx

## Updates the money display with the current balance.
func set_money(amount: int) -> void:
	money_label.text = "Money: %d" % amount
	_play_sfx_throttled()

func _play_sfx_throttled() -> void:
	if _sfx_player == null or _sfx_player.stream == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_sfx_time >= 0.15:
		_sfx_player.play()
		_last_sfx_time = now

## Shows a transient price-band confirmation line.
## Call clear_price_band() or pass an empty string to hide it.
func show_price_band(text: String) -> void:
	price_band_label.text = text

## Hides the price-band line.
func clear_price_band() -> void:
	price_band_label.text = ""
