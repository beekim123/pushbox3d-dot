class_name ResumeStore
extends RefCounted
## Separate optional sidecar only. NEVER opens the progress save.
## Single cooperative writer: lock + optimistic disk-token check + same-dir rename.
## Existing bytes are read-only until a complete ResumeCodec decode is accepted.
## Codec result dictionaries are trusted internal capabilities, not an external API.

const Codec=preload("res://resume_codec.gd")
const FILE_NAME := "resume.json"
const TEMP_NAME := "resume.pending"
const LOCK_NAME := "resume.lock"
var _directory := ""
var _path := ""
var _pending := ""
var _lock := ""
var _inspected := false
var _authorized := false
var _expected_token := ""
var _expected_exists := false
var _configuration_valid := false

func _init(directory: String = "user://fourfold_resume") -> void:
	# A dedicated child of user:// prevents accidental progress-path replacement.
	if directory.length()>512 or not directory.begins_with("user://") or directory=="user://" or ".." in directory or "\\" in directory:
		return
	var root:=ProjectSettings.globalize_path("user://").simplify_path().trim_suffix("/")
	_directory=ProjectSettings.globalize_path(directory).simplify_path().trim_suffix("/")
	if not _directory.begins_with(root+"/"): return
	_path=_directory.path_join(FILE_NAME)
	_pending=_directory.path_join(TEMP_NAME)
	_lock=_directory.path_join(LOCK_NAME)
	_configuration_valid=true

func inspect() -> Dictionary:
	_authorized=false
	_inspected=false
	if not _configuration_valid: return _failure("invalid_store_directory")
	var disk:=_read_disk()
	if disk.status not in ["missing","read"]: return disk
	_inspected=true
	_expected_exists=disk.status=="read"
	_expected_token=disk.get("token","")
	_authorized=not _expected_exists
	disk["writable"]=_authorized
	return disk

func accept_verified_load(restored: Dictionary) -> Dictionary:
	if not _inspected or not _expected_exists: return _failure("no_existing_inspected_checkpoint")
	if restored.get("status")!="restored" or restored.get("validated_format")!=Codec.FORMAT or restored.get("validated_version")!=Codec.VERSION or restored.get("input_token")!=_expected_token:
		return _failure("full_replay_verification_required")
	var disk:=_read_disk()
	if not _matches_expected(disk):
		_authorized=false
		return _failure("checkpoint_changed_since_inspect")
	_authorized=true
	return {"status":"authorized","writable":true,"old_file_preserved":true}

func commit(encoded: Dictionary,current_revision: int) -> Dictionary:
	# Refusal changes neither in-session undo nor existing file. No truncation.
	if not _configuration_valid or not _inspected or not _authorized: return _failure("checkpoint_write_protected")
	if encoded.get("status")!="encoded" or not encoded.get("source_revision") is int or encoded.source_revision!=current_revision:
		return _failure("incomplete_or_stale_checkpoint")
	if not encoded.get("bytes") is PackedByteArray or encoded.bytes.is_empty() or encoded.bytes.size()>Codec.MAX_FILE_BYTES:
		return _failure("invalid_encoded_bytes")
	var bytes: PackedByteArray=encoded.bytes
	var token:=bytes.hex_encode().sha256_text()
	if not encoded.get("blob_token") is String or token!=encoded.blob_token: return _failure("encoded_bytes_changed")
	if DirAccess.make_dir_recursive_absolute(_directory)!=OK or not DirAccess.dir_exists_absolute(_directory): return _failure("directory_unavailable")
	if DirAccess.make_dir_absolute(_lock)!=OK: return _failure("busy_or_abandoned_lock")
	# Lock belongs to THIS commit only after successful atomic mkdir.
	var disk:=_read_disk()
	if not _matches_expected(disk):
		_authorized=false
		_release_lock()
		return _failure("checkpoint_changed_since_inspect")
	if FileAccess.file_exists(_pending) or DirAccess.dir_exists_absolute(_pending):
		_release_lock()
		return _failure("pending_file_requires_manual_review")
	var file:=FileAccess.open(_pending,FileAccess.WRITE)
	if file==null:
		_release_lock()
		return _failure("pending_open_failed")
	file.store_buffer(bytes)
	file.flush()
	var write_error:=file.get_error()
	file.close()
	if write_error!=OK or FileAccess.get_file_as_bytes(_pending)!=bytes:
		DirAccess.remove_absolute(_pending)
		_release_lock()
		return _failure("pending_write_or_verification_failed")
	# Files are in the same directory. The old main file remains untouched until
	# the single rename operation; no delete-old-first fallback is permitted.
	var replaced:=_replace_pending()
	if replaced!=OK:
		DirAccess.remove_absolute(_pending)
		_release_lock()
		return _failure("atomic_replace_failed")
	_expected_exists=true
	_expected_token=token
	_release_lock()
	return {"status":"saved","writable":true,"bytes":bytes.size(),"token":token,"old_file_preserved":false}

func _replace_pending() -> Error:
	return DirAccess.rename_absolute(_pending,_path)

func _release_lock() -> void:
	# remove only our now-empty lock directory, never recursive cleanup.
	DirAccess.remove_absolute(_lock)

func _read_disk() -> Dictionary:
	if DirAccess.dir_exists_absolute(_path): return _failure("checkpoint_is_directory")
	if not FileAccess.file_exists(_path): return {"status":"missing","token":"","old_file_preserved":true}
	var file:=FileAccess.open(_path,FileAccess.READ)
	if file==null: return _failure("checkpoint_unreadable")
	var length:=file.get_length()
	if length<=0 or length>Codec.MAX_FILE_BYTES:
		file.close()
		return _failure("invalid_file_size")
	var bytes:=file.get_buffer(length)
	var error:=file.get_error()
	file.close()
	if bytes.size()!=length or error!=OK: return _failure("checkpoint_read_failed")
	return {"status":"read","bytes":bytes,"token":bytes.hex_encode().sha256_text(),"old_file_preserved":true}

func _matches_expected(disk: Dictionary) -> bool:
	return (disk.status=="read" and _expected_exists and disk.token==_expected_token) or (disk.status=="missing" and not _expected_exists)

func _failure(reason: String) -> Dictionary:
	return {"status":"not_saved","reason":reason,"writable":false,"old_file_preserved":true,"fallback":"fresh_level_on_load_only","keep_current_game":true}
