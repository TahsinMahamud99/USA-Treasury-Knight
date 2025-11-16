extends Node2D

signal dialogue_finished

@export var chars_per_second: float = 40.0
@export var lines_per_page: int = 2
@export var pause_between_pages: float = 1.0

@onready var text_label: Label = $MarginContainer/Label

var _lines: Array[String] = [
	"The dragon has found our nation’s tax funds.",
	"This money keeps schools open and roads paved.",
	"If it steals this wealth, services will collapse.",
	"Only you can stop the creature in time.",
	"Defeat the dragon, protect tax dollars.",
	"Save the people. Save civilization."
]

var _current_page: int = 0


func _ready() -> void:
	await _show_pages()
	# when all pages are done, tell intro.gd
	dialogue_finished.emit()


func _show_pages() -> void:
	while true:
		var start: int = _current_page * lines_per_page
		if start >= _lines.size():
			break

		var end: int = start + lines_per_page
		if end > _lines.size():
			end = _lines.size()

		var page_text: String = ""
		for i in range(start, end):
			if i != start:
				page_text += "\n"
			page_text += _lines[i]

		# type this page
		await _type_page(page_text)

		_current_page += 1

		if _current_page * lines_per_page >= _lines.size():
			break

		# keep visible for a bit
		await get_tree().create_timer(pause_between_pages).timeout

		# erase before next page
		text_label.text = ""


func _type_page(text: String) -> void:
	text_label.text = ""

	var delay: float = 1.0 / chars_per_second

	for i in range(text.length()):
		text_label.text = text.substr(0, i + 1)
		await get_tree().create_timer(delay).timeout
