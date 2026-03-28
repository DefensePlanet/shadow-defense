extends Node
## IAPManager — In-App Purchase framework.
## Addresses: #11 (Monetization layer)
## Enhanced: #31 (Wire up actual store integration), #32 (Rewarded video ads),
## #34 (Battle pass / season pass)
##
## Provides a unified API for IAP across platforms.
## Now with actual store plugin integration for Google Play and App Store.

signal purchase_completed(product_id: String, success: bool)
signal purchase_failed(product_id: String, error: String)
signal products_loaded(products: Array)
signal purchase_restored(product_id: String)
# Enhancement #32: Rewarded ad signals
signal rewarded_ad_completed(placement: String)
signal rewarded_ad_failed(placement: String)

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
	# Economy V2 #45: Starter pack with currency bundle
	"starter_pack_v2": {"name": "Adventurer's Kit", "price": "$4.99", "type": ProductType.NON_CONSUMABLE, "desc": "1000 Gold + 100 Quills + 50 Shards + 5 Gold Chests", "rewards": {"gold": 1000, "quills": 100, "shards": 50, "chests_gold": 5}},
	# Economy V2 #47: Weekend warrior pack
	"weekend_pack": {"name": "Weekend Warrior Pack", "price": "$2.99", "type": ProductType.CONSUMABLE, "desc": "500 Gold + 3 Silver Chests + 2x XP (2hr)", "rewards": {"gold": 500, "chests_silver": 3, "xp_boost": 7200.0}},
	# Economy V2 #48: Gold pack tiers
	"gold_pack_small": {"name": "Gold Sack", "price": "$0.99", "type": ProductType.CONSUMABLE, "desc": "500 Gold", "rewards": {"gold": 500}},
	"gold_pack_medium": {"name": "Gold Pile", "price": "$2.99", "type": ProductType.CONSUMABLE, "desc": "2000 Gold", "rewards": {"gold": 2000}},
	"gold_pack_large": {"name": "Gold Hoard", "price": "$4.99", "type": ProductType.CONSUMABLE, "desc": "5000 Gold + 50 Quills", "rewards": {"gold": 5000, "quills": 50}},
	# Economy V2 #50: Quill packs
	"quill_pack_small": {"name": "Quill Bundle", "price": "$1.99", "type": ProductType.CONSUMABLE, "desc": "200 Quills", "rewards": {"quills": 200}},
	"quill_pack_large": {"name": "Quill Treasury", "price": "$4.99", "type": ProductType.CONSUMABLE, "desc": "600 Quills + 100 Shards", "rewards": {"quills": 600, "shards": 100}},
	# Economy V2 #53: Rescue coin pack (continue after death)
	"rescue_pack": {"name": "Rescue Pack", "price": "$1.99", "type": ProductType.CONSUMABLE, "desc": "5 Rescue Coins — continue from where you fell", "rewards": {"rescue_coins": 5}},
}

var _purchased_items: Array = []  # NON_CONSUMABLE items owned
var _store_available: bool = false
var _platform: String = ""  # "google", "apple", "none"
const PURCHASES_PATH := "user://purchases.json"

# Enhancement #31: Platform billing references
var _google_billing = null  # GodotGooglePlayBilling singleton
var _apple_store = null  # InAppStore singleton

# Enhancement #32: Rewarded ads state
var _ads_available: bool = false
var _ads_removed: bool = false
var _rewarded_ad_ready: bool = false
var _rewarded_ad_placement: String = ""
var _last_ad_time: float = 0.0
const AD_COOLDOWN := 30.0  # Minimum seconds between ads

# Enhancement #34: Battle Pass state
var battle_pass_tier: int = 0
var battle_pass_xp: int = 0
var battle_pass_premium: bool = false
const BATTLE_PASS_MAX_TIER := 50
const BATTLE_PASS_XP_PER_TIER := 500
const BATTLE_PASS_PATH := "user://battle_pass.json"

# Battle Pass rewards (tier -> {free: ..., premium: ...})
var battle_pass_rewards: Dictionary = {}

func _ready() -> void:
	_load_purchases()
	_load_battle_pass()
	_init_store()
	_init_ads()
	_generate_battle_pass_rewards()
	_ads_removed = is_owned("remove_ads")

## Enhancement #31: Initialize platform store
func _init_store() -> void:
	if Engine.has_singleton("GodotGooglePlayBilling"):
		_platform = "google"
		_google_billing = Engine.get_singleton("GodotGooglePlayBilling")
		_store_available = true
		# Connect Google Play Billing signals
		_google_billing.connected.connect(_on_google_connected)
		_google_billing.disconnected.connect(_on_google_disconnected)
		_google_billing.purchase_acknowledged.connect(_on_google_purchase_acknowledged)
		_google_billing.purchase_consumed.connect(_on_google_purchase_consumed)
		_google_billing.purchases_updated.connect(_on_google_purchases_updated)
		_google_billing.purchase_error.connect(_on_google_purchase_error)
		_google_billing.sku_details_query_completed.connect(_on_google_sku_details)
		_google_billing.startConnection()
	elif Engine.has_singleton("InAppStore"):
		_platform = "apple"
		_apple_store = Engine.get_singleton("InAppStore")
		_store_available = true
	else:
		_platform = "none"
		_store_available = false

## Enhancement #32: Initialize ad SDK
func _init_ads() -> void:
	# Check for ad plugin (AdMob, IronSource, etc.)
	if Engine.has_singleton("AdMob"):
		var admob = Engine.get_singleton("AdMob")
		_ads_available = true
	elif Engine.has_singleton("GodotAdMob"):
		_ads_available = true
	else:
		_ads_available = false

## Check if IAP is available
func is_available() -> bool:
	return _store_available

## Purchase a product
func purchase(product_id: String) -> void:
	if not products.has(product_id):
		purchase_failed.emit(product_id, "Unknown product")
		return

	if AnalyticsManager:
		AnalyticsManager.track_purchase(product_id, "real", 0)

	if not _store_available:
		# Simulate purchase for testing (debug builds only)
		if OS.is_debug_build():
			_on_purchase_success(product_id)
		else:
			purchase_failed.emit(product_id, "Store not available")
		return

	match _platform:
		"google":
			if _google_billing:
				_google_billing.purchase(product_id)
		"apple":
			if _apple_store:
				var result = _apple_store.purchase({"product_id": product_id})
				if result != OK:
					purchase_failed.emit(product_id, "Apple purchase initiation failed")

## Check if a non-consumable is owned
func is_owned(product_id: String) -> bool:
	return product_id in _purchased_items

## Restore purchases (iOS requirement, also useful on Android)
func restore_purchases() -> void:
	match _platform:
		"apple":
			if _apple_store:
				_apple_store.restore_purchases()
		"google":
			if _google_billing:
				_google_billing.queryPurchases("inapp")
				_google_billing.queryPurchases("subs")
	# Also load local cache as fallback
	_load_purchases()

## Enhancement #32: Show rewarded video ad
func show_rewarded_ad(placement: String = "default") -> void:
	if _ads_removed:
		# Ads removed — grant reward directly
		rewarded_ad_completed.emit(placement)
		return
	if not _ads_available:
		rewarded_ad_failed.emit(placement)
		return
	var now = Time.get_ticks_msec() / 1000.0
	if now - _last_ad_time < AD_COOLDOWN:
		rewarded_ad_failed.emit(placement)
		return
	_rewarded_ad_placement = placement
	_last_ad_time = now
	# Show via ad plugin
	if Engine.has_singleton("AdMob"):
		Engine.get_singleton("AdMob").showRewardedVideo()
	else:
		# No ad SDK — grant reward in debug
		if OS.is_debug_build():
			rewarded_ad_completed.emit(placement)
		else:
			rewarded_ad_failed.emit(placement)

## Enhancement #32: Check if rewarded ad is available
func is_rewarded_ad_ready() -> bool:
	if _ads_removed:
		return true  # Always "ready" if ads removed (free reward)
	if not _ads_available:
		return false
	var now = Time.get_ticks_msec() / 1000.0
	return now - _last_ad_time >= AD_COOLDOWN

## Enhancement #34: Add battle pass XP
func add_battle_pass_xp(amount: int) -> int:
	var tiers_gained := 0
	battle_pass_xp += amount
	while battle_pass_xp >= BATTLE_PASS_XP_PER_TIER and battle_pass_tier < BATTLE_PASS_MAX_TIER:
		battle_pass_xp -= BATTLE_PASS_XP_PER_TIER
		battle_pass_tier += 1
		tiers_gained += 1
	_save_battle_pass()
	return tiers_gained

## Enhancement #34: Get battle pass reward for a tier
func get_battle_pass_reward(tier: int, premium: bool = false) -> Dictionary:
	if not battle_pass_rewards.has(tier):
		return {}
	if premium and not battle_pass_premium:
		return {}
	return battle_pass_rewards[tier].get("premium" if premium else "free", {})

## Enhancement #34: Check if a tier's reward is claimed
func is_tier_claimed(tier: int) -> bool:
	return tier < battle_pass_tier

## Enhancement #34: Generate battle pass reward table
func _generate_battle_pass_rewards() -> void:
	for i in range(BATTLE_PASS_MAX_TIER + 1):
		var free_reward = {}
		var premium_reward = {}
		# Free tier: gold, crystals, gear chests on milestone tiers
		if i % 5 == 0 and i > 0:
			free_reward = {"type": "crystals", "amount": 25 + i * 2}
		elif i % 3 == 0:
			free_reward = {"type": "gold", "amount": 200 + i * 50}
		else:
			free_reward = {"type": "gold", "amount": 100 + i * 20}
		# Premium tier: better rewards + exclusive content
		if i % 10 == 0 and i > 0:
			premium_reward = {"type": "skin", "hero_index": (i / 10) - 1}
		elif i % 5 == 0:
			premium_reward = {"type": "gear_chest", "amount": 2}
		else:
			premium_reward = {"type": "crystals", "amount": 15 + i * 3}
		battle_pass_rewards[i] = {"free": free_reward, "premium": premium_reward}

# --- Google Play Billing callbacks ---
func _on_google_connected() -> void:
	if _google_billing:
		_google_billing.querySkuDetails(products.keys(), "inapp")

func _on_google_disconnected() -> void:
	_store_available = false

func _on_google_purchases_updated(query_result: int, purchases: Array) -> void:
	if query_result == OK:
		for purchase_data in purchases:
			var product_id = purchase_data.get("sku", "")
			if products.has(product_id):
				var product = products[product_id]
				if product.get("type") == ProductType.CONSUMABLE:
					_google_billing.consumePurchase(purchase_data.get("purchaseToken", ""))
				else:
					_google_billing.acknowledgePurchase(purchase_data.get("purchaseToken", ""))
				_on_purchase_success(product_id)

func _on_google_purchase_acknowledged(_token: String) -> void:
	pass

func _on_google_purchase_consumed(_token: String) -> void:
	pass

func _on_google_purchase_error(code: int, msg: String) -> void:
	purchase_failed.emit("", "Google Play error %d: %s" % [code, msg])

func _on_google_sku_details(_result: int, _details: Array) -> void:
	products_loaded.emit(_details)

func _on_purchase_success(product_id: String) -> void:
	var product = products.get(product_id, {})
	match product.get("type", ProductType.CONSUMABLE):
		ProductType.NON_CONSUMABLE, ProductType.SUBSCRIPTION:
			if product_id not in _purchased_items:
				_purchased_items.append(product_id)
				if product_id == "remove_ads":
					_ads_removed = true
		ProductType.CONSUMABLE:
			pass  # Consumed items handled by game logic
	_save_purchases()
	purchase_completed.emit(product_id, true)
	if TouchManager:
		TouchManager.haptic(TouchManager.HapticStyle.SUCCESS)

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

func _save_battle_pass() -> void:
	var data = {
		"tier": battle_pass_tier,
		"xp": battle_pass_xp,
		"premium": battle_pass_premium,
	}
	var file = FileAccess.open(BATTLE_PASS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func _load_battle_pass() -> void:
	if not FileAccess.file_exists(BATTLE_PASS_PATH):
		return
	var file = FileAccess.open(BATTLE_PASS_PATH, FileAccess.READ)
	if not file:
		return
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		battle_pass_tier = int(json.data.get("tier", 0))
		battle_pass_xp = int(json.data.get("xp", 0))
		battle_pass_premium = bool(json.data.get("premium", false))
