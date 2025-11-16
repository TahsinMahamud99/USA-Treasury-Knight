extends Node

const BASE_URL := "https://api.usaspending.gov"

# Default: Virginia (FIPS 51)
@export var target_state_fips: String = "51"
@export var target_fiscal_year: int = 2023

@onready var http: HTTPRequest = null

enum RequestType {
	STATE_PROFILE,
	TOPTIER_AGENCIES,
	AGENCY_BUDGET_RESOURCES,
	AGENCY_OBLIGATIONS_BY_CATEGORY
}

var _request_queue: Array[Dictionary] = []
var _current_request: Dictionary = {}

var _quiz_data: Dictionary = {
	"state_fips": "",
	"fiscal_year": 0,
	"state_profile": {},
	"agencies": {
		"toptier_list": [],
		"detailed": {}  # agency_name -> { budget_by_year, obligations_by_award_category, obligations_total }
	}
}


func _ready() -> void:
	# ---------- EARLY EXIT IF JSON ALREADY EXISTS ----------
	var save_path: String = "res://data/state_quiz_%s.json" % target_state_fips
	if FileAccess.file_exists(save_path):
		print("📁 state_quiz JSON already exists at", save_path, "→ skipping USAspending fetch.")
		return
	# -------------------------------------------------------

	http = get_node_or_null("HTTPRequest")
	if http == null:
		push_error("ERROR: No child HTTPRequest node found.")
		return

	if not http.request_completed.is_connected(Callable(self, "_on_request_completed")):
		http.request_completed.connect(Callable(self, "_on_request_completed"))

	_quiz_data["state_fips"] = target_state_fips
	_quiz_data["fiscal_year"] = target_fiscal_year

	_build_initial_queue()
	_start_next_request()


# =====================================================
# QUEUE CONSTRUCTION
# =====================================================

func _build_initial_queue() -> void:
	_request_queue.clear()

	# 1) State profile
	var state_url: String = "%s/api/v2/recipient/state/%s/?year=%d" % [
		BASE_URL,
		target_state_fips,
		target_fiscal_year
	]

	_request_queue.append({
		"type": RequestType.STATE_PROFILE,
		"method": HTTPClient.METHOD_GET,
		"url": state_url,
		"meta": {
			"state_fips": target_state_fips,
			"year": target_fiscal_year
		}
	})

	# 2) Top-tier agencies
	var agencies_url: String = "%s/api/v2/references/toptier_agencies/" % [BASE_URL]

	_request_queue.append({
		"type": RequestType.TOPTIER_AGENCIES,
		"method": HTTPClient.METHOD_GET,
		"url": agencies_url,
		"meta": {}
	})


func _enqueue_agency_detail(agency: Dictionary) -> void:
	if not agency.has("toptier_code"):
		return

	var code: String = str(agency.get("toptier_code", ""))
	var name: String = str(agency.get("agency_name", agency.get("name", "")))

	if code == "" or name == "":
		return

	# A) Budgetary resources by year
	var br_url: String = "%s/api/v2/agency/%s/budgetary_resources/" % [BASE_URL, code]

	_request_queue.append({
		"type": RequestType.AGENCY_BUDGET_RESOURCES,
		"method": HTTPClient.METHOD_GET,
		"url": br_url,
		"meta": {
			"agency_name": name,
			"toptier_code": code
		}
	})

	# B) Obligations by award category
	var ob_url: String = "%s/api/v2/agency/%s/obligations_by_award_category/?fiscal_year=%d" % [
		BASE_URL,
		code,
		target_fiscal_year
	]

	_request_queue.append({
		"type": RequestType.AGENCY_OBLIGATIONS_BY_CATEGORY,
		"method": HTTPClient.METHOD_GET,
		"url": ob_url,
		"meta": {
			"agency_name": name,
			"toptier_code": code,
			"year": target_fiscal_year
		}
	})


func _start_next_request() -> void:
	if _request_queue.is_empty():
		_finish_and_save()
		return

	_current_request = _request_queue.pop_front()

	var url: String = _current_request["url"]
	var method: int = _current_request["method"]
	var headers: PackedStringArray = PackedStringArray()
	var body_str: String = ""

	if _current_request.has("body"):
		body_str = str(_current_request["body"])
		headers.append("Content-Type: application/json")

	var err: Error = http.request(url, headers, method, body_str)
	if err != OK:
		push_error("ERROR: Failed to start HTTP request (%s): %s" % [url, err])
		_start_next_request()
		return

	print("→ Started request:", url)


# =====================================================
# RESPONSE HANDLER
# =====================================================

func _on_request_completed(
		result: int,
		response_code: int,
		_headers: PackedStringArray,
		body: PackedByteArray
) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("Request failed with result code: %d" % result)
		_start_next_request()
		return

	if response_code != 200:
		push_error("HTTP %d for URL %s" % [response_code, _current_request.get("url", "")])
		_start_next_request()
		return

	var text: String = body.get_string_from_utf8()
	var parsed_variant: Variant = JSON.parse_string(text)
	if typeof(parsed_variant) != TYPE_DICTIONARY:
		push_error("Unexpected JSON format for URL %s" % _current_request.get("url", ""))
		_start_next_request()
		return

	var data: Dictionary = parsed_variant as Dictionary
	var req_type: int = _current_request["type"]

	match req_type:
		RequestType.STATE_PROFILE:
			_handle_state_profile_response(data)
		RequestType.TOPTIER_AGENCIES:
			_handle_toptier_agencies_response(data)
		RequestType.AGENCY_BUDGET_RESOURCES:
			_handle_agency_budget_resources_response(data)
		RequestType.AGENCY_OBLIGATIONS_BY_CATEGORY:
			_handle_agency_obligations_by_category_response(data)
		_:
			push_error("Unknown request type in response handler")

	_start_next_request()


# =====================================================
# PARSERS
# =====================================================

func _handle_state_profile_response(data: Dictionary) -> void:
	_quiz_data["state_profile"] = data
	print("✓ State profile loaded for FIPS:", _quiz_data["state_fips"])


func _handle_toptier_agencies_response(data: Dictionary) -> void:
	var results_any: Variant = data.get("results", [])
	var results: Array = []
	if typeof(results_any) == TYPE_ARRAY:
		results = results_any as Array

	_quiz_data["agencies"]["toptier_list"] = results
	print("✓ Loaded", results.size(), "top-tier agencies")

	# Pick some interesting agencies (NASA, DoD, Treasury, etc.)
	var nasa: Dictionary = {}
	var dod: Dictionary = {}
	var treasury: Dictionary = {}

	for item_any in results:
		if typeof(item_any) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_any as Dictionary
		var name: String = str(item.get("agency_name", item.get("name", "")))

		match name:
			"National Aeronautics and Space Administration":
				nasa = item
			"Department of Defense":
				dod = item
			"Department of the Treasury":
				treasury = item
			_:
				pass

	if nasa.size() > 0:
		print("  • Found NASA:", nasa.get("toptier_code", ""))
		_enqueue_agency_detail(nasa)

	if dod.size() > 0:
		print("  • Found DoD:", dod.get("toptier_code", ""))
		_enqueue_agency_detail(dod)

	if treasury.size() > 0:
		print("  • Found Treasury:", treasury.get("toptier_code", ""))
		_enqueue_agency_detail(treasury)


func _handle_agency_budget_resources_response(data: Dictionary) -> void:
	var meta: Dictionary = _current_request.get("meta", {})
	var agency_name: String = str(meta.get("agency_name", "Unknown Agency"))

	if not _quiz_data["agencies"]["detailed"].has(agency_name):
		_quiz_data["agencies"]["detailed"][agency_name] = {}

	var detail: Dictionary = _quiz_data["agencies"]["detailed"][agency_name]

	var by_year_any: Variant = data.get("agency_data_by_year", [])
	if typeof(by_year_any) == TYPE_ARRAY:
		detail["budget_by_year"] = by_year_any
	else:
		detail["budget_by_year"] = []

	_quiz_data["agencies"]["detailed"][agency_name] = detail
	print("✓ Stored budget_by_year for", agency_name)


func _handle_agency_obligations_by_category_response(data: Dictionary) -> void:
	var meta: Dictionary = _current_request.get("meta", {})
	var agency_name: String = str(meta.get("agency_name", "Unknown Agency"))

	if not _quiz_data["agencies"]["detailed"].has(agency_name):
		_quiz_data["agencies"]["detailed"][agency_name] = {}

	var detail: Dictionary = _quiz_data["agencies"]["detailed"][agency_name]

	var res_any: Variant = data.get("results", [])
	if typeof(res_any) == TYPE_ARRAY:
		detail["obligations_by_award_category"] = res_any
	else:
		detail["obligations_by_award_category"] = []

	detail["obligations_total"] = data.get("total_aggregated_amount", 0.0)

	_quiz_data["agencies"]["detailed"][agency_name] = detail
	print("✓ Stored obligations_by_award_category for", agency_name)


# =====================================================
# FINAL SAVE
# =====================================================

func _finish_and_save() -> void:
	var folder_abs: String = ProjectSettings.globalize_path("res://data")
	if not DirAccess.dir_exists_absolute(folder_abs):
		push_error("Missing folder res://data – create it in Godot!")
		return

	var save_path: String = "res://data/state_quiz_%s.json" % target_state_fips
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot save JSON to: " + save_path)
		return

	file.store_string(JSON.stringify(_quiz_data, "\t"))
	file.close()

	print("✅ [SAVED] →", save_path)
