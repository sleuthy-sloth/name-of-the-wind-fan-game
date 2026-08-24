## GameState
# Session state spine for "The Name of the Wind" fan game.
# Holds act/day/time state, Alar, money, relationships, reputation,
# quest progress, and world flags.
extends Node

@export var act: int = 1
@export var day: int = 1
@export var time_block: String = "morning"
@export var alar: float = 100.0
@export var max_alar: float = 100.0
@export var money: int = 0

var relationships: Dictionary = {}   # id -> float
var reputation: Dictionary = {}      # group -> int
var quest_states: Dictionary = {}    # quest_id -> state
var world_flags: Dictionary = {}     # flag_id -> true

func set_flag(flag_id: String) -> void:
	world_flags[flag_id] = true

func has_flag(flag_id: String) -> bool:
	return world_flags.get(flag_id, false) == true

func to_dict() -> Dictionary:
	return {
		"act": act,
		"day": day,
		"time_block": time_block,
		"alar": alar,
		"max_alar": max_alar,
		"money": money,
		"relationships": relationships.duplicate(),
		"reputation": reputation.duplicate(),
		"quest_states": quest_states.duplicate(),
		"world_flags": world_flags.duplicate(),
	}

func from_dict(d: Dictionary) -> void:
	act = d.get("act", act)
	day = d.get("day", day)
	time_block = d.get("time_block", time_block)
	alar = d.get("alar", alar)
	max_alar = d.get("max_alar", max_alar)
	money = d.get("money", money)
	relationships = d.get("relationships", relationships).duplicate()
	reputation = d.get("reputation", reputation).duplicate()
	quest_states = d.get("quest_states", quest_states).duplicate()
	world_flags = d.get("world_flags", world_flags).duplicate()
