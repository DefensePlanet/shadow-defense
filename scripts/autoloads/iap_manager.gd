extends Node
## IAPManager — In-App Purchase framework.
## Addresses: #11 (Monetization layer)
##
## Provides a unified API for IAP across platforms.
## Actual store integration requires platform-specific plugins.

signal purchase_completed(product_id: String, success: bool)
signal purchase_failed(product_id: String, error: String)
signal products_loaded(products: Array)

enum ProductType { CONSUMABLE, NON_CONSUMABLE, SUBSCRIPTION }

# Product catalog
var products: Dictionary = {
	"crystal_pack_small": {"name": "Crystal Pouch", "price": "$0.99", "type": ProductType.CONSUMABLE, "crystals": 100},
	"crystal_pack_medium": {"name": "Crystal Chest", "price": "$4.99", "type": ProductType.CONSUMABLE, "crystals": 600},
	"crystal_pack_large": {"name": "Crystal Vault", "price": "$9.99", "type": ProductType.CONSUMABLE, "crystals": 1400},
	"crystal_pack_mega": {"name": "Crystal Treasury", "price": "$19.99", "type": ProductType.CONSUMABLE, "crystals": 3200},
	"starter_pack": {"name": "Starter Bundle", "price": "$2.99", "type": ProductType.NON_CONSUMABLE, "desc": "500 Gold + 50 Crystals + 3 Gear Chests"},
	"double_cash": {"name": "Double Cash", "price": "$4.99", "type": ProductType.NON_CONSUMABLE, "desc": "Permanently double all gold earned"},
	"remove_ads": {"name": "Remove Ads", "price": "$3.99", "type": ProductType.NON_CONSUMABLE, "desc": "Remove all advertisements"},
	"season_pass": {"name": "Commander's Pass Premium", "price": "$9.99", "type": ProductType.SUBSCRIPTION, "desc": "Premium seasonal content and rewards"},
}

var _purchased_items: Array = []  # NON_CONSUMABLE items owned
var _store_available: bool = false
const PURCHASES_PATH := "user://purchases.json"

func _ready() -> void:
	_load_purchases()
	_init_store()

func _init_store() -> void:
	# Check for platform-specific IAP plugin
	if Engine.has_singleton("GodotGooglePlayBilling"):
		_store_available = true
		# Connect billing signals here
	elif Engine.has_singleton("InAppStore"):
		_store_available = true
		# Connect App Store signals here
	else:
		_store_available = false

## Check if IAP is available
func is_available() -> bool:
	return _store_available

## Purchase a product
func purchase(product_id: String) -> void:
	if not products.has(product_id):
		purchase_failed.emit(product_id, "Unknown product")
		return
	if not _store_available:
		# Simulate purchase for testing
		_on_purchase_success(product_id)
		return
	# Platform-specific purchase flow would go here
	# For now, emit failure if no store plugin
	purchase_failed.emit(product_id, "Store not configured")

## Check if a non-consumable is owned
func is_owned(product_id: String) -> bool:
	return product_id in _purchased_items

## Restore purchases (iOS requirement)
func restore_purchases() -> void:
	if _store_available and Engine.has_singleton("InAppStore"):
		# Trigger restore flow
		pass
	# Load local cache as fallback
	_load_purchases()

func _on_purchase_success(product_id: String) -> void:
	var product = products.get(product_id, {})
	match product.get("type", ProductType.CONSUMABLE):
		ProductType.NON_CONSUMABLE, ProductType.SUBSCRIPTION:
			if product_id not in _purchased_items:
				_purchased_items.append(product_id)
		ProductType.CONSUMABLE:
			pass  # Consumed items handled by game logic
	_save_purchases()
	purchase_completed.emit(product_id, true)

func _save_purchases() -> void:
	var file = FileAccess.open(PURCHASES_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"purchased": _purchased_items}))
		file.close()

func _load_purchases() -> void:
	if not FileAccess.file_exists(PURCHASES_PATH):
		return
	var file = FileAccess.open(PURCHASES_PATH, FileAccess.READ)
	if not file:
		return
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		_purchased_items = json.data.get("purchased", [])
