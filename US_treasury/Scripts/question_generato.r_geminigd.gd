extends Node

# -------- PATHS --------
const API_KEY_PATH: String = "res://gemni api key/gemni_api_key.txt"
const STATE_JSON_PATH: String = "res://data/state_quiz_51.json"

# Absolute Windows directory where questions JSON will be saved
const OUTPUT_DIR: String = "C:/Users/Tahsin/Documents/UST_data"

# How many questions we want to generate
const TARGET_QUESTION_COUNT: int = 20

# Gemini endpoint
const GEMINI_ENDPOINT_BASE: String = \
	"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=%s"

@onready var http: HTTPRequest = $HTTPRequest

var _api_key: String = ""
var _endpoint_url: String = ""

var _state_data: Dictionary = {}
var _facts: Array = []
var _fact_queue: Array = []
var _pending_fact: String = ""

var _generated_questions: Array = []


# ========================= READY =========================
func _ready() -> void:
	_load_api_key()

	if _api_key == "":
		push_error("Gemini API key missing.")
		return

	_endpoint_url = GEMINI_ENDPOINT_BASE % _api_key

	if not http.request_completed.is_connected(Callable(self, "_on_http_request_completed")):
		http.request_completed.connect(Callable(self, "_on_http_request_completed"))

	_load_state_data()

	if _facts.size() == 0:
		push_error("No facts found in state JSON.")
		return

	# ---- Build queue to reach TARGET_QUESTION_COUNT ----
	_fact_queue.clear()
	var base_facts: Array = _facts.duplicate()

	if base_facts.is_empty():
		push_error("No base facts to build question queue.")
		return

	if base_facts.size() >= TARGET_QUESTION_COUNT:
		# If we already have enough unique facts, just cut to 50
		base_facts.resize(TARGET_QUESTION_COUNT)
		_fact_queue = base_facts
	else:
		# Otherwise, cycle through facts until we reach 50
		var i: int = 0
		while _fact_queue.size() < TARGET_QUESTION_COUNT:
			var fact_variant: Variant = base_facts[i % base_facts.size()]
			_fact_queue.append(fact_variant)
			i += 1

	_generated_questions.clear()

	print("[QuestionGenerator] Starting with", _fact_queue.size(), "facts (target =", TARGET_QUESTION_COUNT, ").")
	_start_next_fact()


# ========================= LOAD API KEY =========================
func _load_api_key() -> void:
	var file: FileAccess = FileAccess.open(API_KEY_PATH, FileAccess.READ)
	if file == null:
		push_error("Cannot open: " + API_KEY_PATH)
		return

	_api_key = file.get_as_text().strip_edges()
	file.close()

	print("[Gemini] API key loaded (length = ", _api_key.length(), ")")


# ========================= NUMBER FORMATTER =========================
# Turn numbers into readable money with units:
#  - 78_300     -> "$78k"
#  - 1_250_000  -> "$1.3M"
#  - 3_800_000_000 -> "$3.8B"
func _approx_number(value: float) -> String:
	var abs_val: float = abs(value)

	if abs_val >= 1_000_000_000.0:
		var b: float = round(abs_val / 1_000_000_000.0 * 10.0) / 10.0
		return "$%sB" % str(b)
	elif abs_val >= 1_000_000.0:
		var m: float = round(abs_val / 1_000_000.0 * 10.0) / 10.0
		return "$%sM" % str(m)
	elif abs_val >= 1_000.0:
		var k: float = round(abs_val / 1_000.0)
		return "$%sk" % str(k)
	else:
		return "$%d" % int(round(abs_val))


# ========================= LOAD STATE JSON =========================
func _load_state_data() -> void:
	if not FileAccess.file_exists(STATE_JSON_PATH):
		push_error("Missing state JSON: " + STATE_JSON_PATH)
		return

	var f: FileAccess = FileAccess.open(STATE_JSON_PATH, FileAccess.READ)
	if f == null:
		push_error("Cannot open: " + STATE_JSON_PATH)
		return

	var json_text: String = f.get_as_text()
	f.close()

	var parsed: Variant = JSON.parse_string(json_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid state JSON format.")
		return

	_state_data = parsed as Dictionary
	_build_facts_from_state_data()

	print("[StateJSON] Loaded state data from:", STATE_JSON_PATH)


# ========================= CREATE FACTS =========================
func _build_facts_from_state_data() -> void:
	_facts.clear()

	var fy: int = int(_state_data.get("fiscal_year", 0))

	# ----- State profile -----
	var profile_any: Variant = _state_data.get("state_profile", {})
	var profile: Dictionary = {}
	if typeof(profile_any) == TYPE_DICTIONARY:
		profile = profile_any as Dictionary

	if profile.size() > 0:
		var name: String = str(profile.get("name", "this state"))
		var prime_amt_any: Variant = profile.get("total_prime_amount", null)

		if typeof(prime_amt_any) == TYPE_INT or typeof(prime_amt_any) == TYPE_FLOAT:
			var prime_val: float = float(prime_amt_any)
			var prime_str: String = _approx_number(prime_val)
			_facts.append(
				"In fiscal year %d, the federal government awarded about %s in prime awards to %s."
				% [fy, prime_str, name]
			)

	# ----- Agencies (using the 'agencies.detailed' map if present) -----
	var agencies_any: Variant = _state_data.get("agencies", {})
	var agencies: Dictionary = {}
	if typeof(agencies_any) == TYPE_DICTIONARY:
		agencies = agencies_any as Dictionary

	var detailed_any: Variant = agencies.get("detailed", {})
	var detailed: Dictionary = {}
	if typeof(detailed_any) == TYPE_DICTIONARY:
		detailed = detailed_any as Dictionary

	for agency_name_key in detailed.keys():
		var det_any: Variant = detailed[agency_name_key]
		if typeof(det_any) != TYPE_DICTIONARY:
			continue

		var det: Dictionary = det_any as Dictionary
		var ob_any: Variant = det.get("obligations_total", null)

		if typeof(ob_any) == TYPE_INT or typeof(ob_any) == TYPE_FLOAT:
			var ob_val: float = float(ob_any)
			var ob_str: String = _approx_number(ob_val)
			_facts.append(
				"In fiscal year %d, %s had about %s in total obligations."
				% [fy, str(agency_name_key), ob_str]
			)

	print("[Facts] Total facts generated:", _facts.size())


# ========================= FACT PROCESSING =========================
func _start_next_fact() -> void:
	if _fact_queue.is_empty():
		print("[Generator] Completed all facts. Saving...")
		_save_questions_json()
		return

	var f: Variant = _fact_queue.pop_front()
	_pending_fact = str(f)
	generate_two_choice_question(_pending_fact)


# ========================= GEMINI REQUEST =========================
func generate_two_choice_question(fact_text: String) -> void:
	if http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		push_error("Request already in progress.")
		return

	var headers: PackedStringArray = PackedStringArray(["Content-Type: application/json"])

	var prompt: String = """
Create ONE trivia question based only on this fact:

%s

Rules:
- Exactly TWO answer options.
- One correct, one clearly incorrect.
- Use only information consistent with the fact (do not invent different numbers).
- Return ONLY JSON in this form:
{"question":"...", "options":["opt1","opt2"], "answer":"exact_correct_option"}
""" % fact_text

	var body: Dictionary = {
		"contents": [
			{
				"parts": [
					{"text": prompt}
				]
			}
		]
	}

	var json_body: String = JSON.stringify(body)

	var err: Error = http.request(
		_endpoint_url,
		headers,
		HTTPClient.METHOD_POST,
		json_body
	)

	if err != OK:
		push_error("HTTP Request failed: " + str(err))
	else:
		print("\n--- Sending to Gemini ---\nFACT:", fact_text)


# ========================= GEMINI RESPONSE =========================
func _on_http_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	print("\n--- Gemini Response Received ---")
	print("Result:", result, "HTTP:", response_code)

	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("Gemini request failed with result %d" % result)
		_start_next_fact()
		return

	if response_code != 200:
		var raw_err: String = body.get_string_from_utf8()
		push_error("Gemini Error: " + str(response_code) + " body: " + raw_err)
		_start_next_fact()
		return

	var raw: String = body.get_string_from_utf8()
	var outer_variant: Variant = JSON.parse_string(raw)

	if typeof(outer_variant) != TYPE_DICTIONARY:
		push_error("Invalid Gemini JSON.")
		_start_next_fact()
		return

	var outer: Dictionary = outer_variant as Dictionary

	var candidates_any: Variant = outer.get("candidates", [])
	if typeof(candidates_any) != TYPE_ARRAY:
		push_error("candidates not Array.")
		_start_next_fact()
		return
	var candidates: Array = candidates_any as Array

	if candidates.size() == 0:
		push_error("No candidates returned.")
		_start_next_fact()
		return

	var first_any: Variant = candidates[0]
	if typeof(first_any) != TYPE_DICTIONARY:
		push_error("First candidate is not Dictionary.")
		_start_next_fact()
		return
	var first: Dictionary = first_any as Dictionary

	var content_any: Variant = first.get("content", {})
	if typeof(content_any) != TYPE_DICTIONARY:
		push_error("content not Dictionary.")
		_start_next_fact()
		return
	var content: Dictionary = content_any as Dictionary

	var parts_any: Variant = content.get("parts", [])
	if typeof(parts_any) != TYPE_ARRAY:
		push_error("parts not Array.")
		_start_next_fact()
		return
	var parts: Array = parts_any as Array

	if parts.size() == 0:
		push_error("No parts in content.")
		_start_next_fact()
		return

	var part0_any: Variant = parts[0]
	if typeof(part0_any) != TYPE_DICTIONARY:
		push_error("First part not Dictionary.")
		_start_next_fact()
		return
	var part0: Dictionary = part0_any as Dictionary

	var inner_text: String = str(part0.get("text", ""))
	print("Inner text from Gemini:", inner_text)

	# Remove ```json ... ``` wrappers if present
	var cleaned: String = inner_text.strip_edges()
	cleaned = cleaned.replace("```json", "")
	cleaned = cleaned.replace("```", "")
	cleaned = cleaned.strip_edges()

	var inner_variant: Variant = JSON.parse_string(cleaned)
	if typeof(inner_variant) != TYPE_DICTIONARY:
		push_error("Inner Gemini text not valid JSON: " + cleaned)
		_start_next_fact()
		return
	var inner: Dictionary = inner_variant as Dictionary

	var question: String = str(inner.get("question", ""))
	var options_any: Variant = inner.get("options", [])
	if typeof(options_any) != TYPE_ARRAY:
		push_error("options not Array.")
		_start_next_fact()
		return
	var options: Array = options_any as Array
	var answer: String = str(inner.get("answer", ""))

	var q_entry: Dictionary = {
		"question": question,
		"options": options,
		"answer": answer
	}
	_generated_questions.append(q_entry)

	print("\n=== Gemini Question Generated ===")
	print("Fact used: ", _pending_fact)
	print("Question: ", question)
	print("Options:  ", options)
	print("Answer:   ", answer)
	print("=================================\n")

	_start_next_fact()


# ========================= SAVE QUESTIONS JSON =========================
func _save_questions_json() -> void:
	var err: Error = DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	if err != OK and err != ERR_ALREADY_EXISTS:
		push_error("Cannot create directory: " + OUTPUT_DIR + " (err=" + str(err) + ")")
		return

	var fips: String = str(_state_data.get("state_fips", "unknown"))
	var output_path: String = "%s/generated_questions_state_%s.json" % [OUTPUT_DIR, fips]

	var final_json: Dictionary = {
		"source_state_file": STATE_JSON_PATH,
		"questions": _generated_questions
	}

	var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write file to: " + output_path)
		return

	file.store_string(JSON.stringify(final_json, "\t"))
	file.close()

	print("[SAVED] -> ", output_path)
