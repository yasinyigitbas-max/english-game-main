## Economy (autoload "Economy"): wallet, item catalogue, shop prices, transactions. Saveable via to_dict()/from_dict().
## Money is stored as INTEGER cents to avoid float rounding.  format(1250) -> "$12.50"
##   Economy.balance()  Economy.earn(500, "job")  Economy.spend(150, "bus fare")  Economy.buy("apple", "corner_shop", 2)
extends Node

signal balance_changed(cents: int)
signal transaction(entry: Dictionary)

const ITEMS_PATH := "res://data/economy/items.json"
const SHOPS_PATH := "res://data/economy/shops.json"
const SYMBOL: = "£"
const START_CENTS := 2000

var wallet := START_CENTS
var history: Array = []              # [{t, amount, reason, balance}]
var items := {}                  # id -> {name, name_tr, base_price, category}
var shops := {}                  # id -> {name, name_tr, stock: {item_id: price_cents or null=base}, markup}
var inventory := {}              # item_id -> qty

func _ready() -> void:
	items = _load_json(ITEMS_PATH).get("items", {})
	shops = _load_json(SHOPS_PATH).get("shops", {})

func _load_json(p: String) -> Dictionary:
	if not FileAccess.file_exists(p): return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(p))
	return d if d is Dictionary else {}

func balance() -> int: return wallet
func can_afford(cents: int) -> bool: return wallet >= cents
func format(cents: int) -> String: return "%s%d.%02d" % [SYMBOL, cents / 100, absi(cents) % 100]

func earn(cents: int, reason := "") -> void: _apply(absi(cents), reason)

func spend(cents: int, reason := "") -> bool:
	if not can_afford(cents): return false
	_apply(-absi(cents), reason); return true

## price of an item in a shop (cents), -1 if the shop does not sell it
func price_of(item_id: String, shop_id: String) -> int:
	var shop: Dictionary = shops.get(shop_id, {})
	var stock: Dictionary = shop.get("stock", {})
	if not stock.has(item_id) or not items.has(item_id): return -1
	if stock[item_id] != null: return int(stock[item_id])
	return int(round(float(items[item_id].base_price) * float(shop.get("markup", 1.0))))

func shop_items(shop_id: String) -> Array:
	var out := []
	for id in shops.get(shop_id, {}).get("stock", {}): out.append({"id": id, "price": price_of(id, shop_id), "item": items.get(id, {})})
	return out

func buy(item_id: String, shop_id: String, qty := 1) -> bool:
	var p := price_of(item_id, shop_id)
	if p < 0 or not spend(p * qty, "buy %dx %s @ %s" % [qty, item_id, shop_id]): return false
	inventory[item_id] = int(inventory.get(item_id, 0)) + qty; return true

func _apply(delta: int, reason: String) -> void:
	wallet += delta
	var e := {"t": WorldState.stamp() if has_node("/root/WorldState") else "", "amount": delta, "reason": reason, "balance": wallet}
	history.append(e); if history.size() > 200: history.pop_front()
	transaction.emit(e); balance_changed.emit(wallet)

func to_dict() -> Dictionary: return {"wallet": wallet, "inventory": inventory, "log": history.slice(-50)}
func from_dict(d: Dictionary) -> void:
	wallet = int(d.get("wallet", START_CENTS)); inventory = d.get("inventory", {}); history = d.get("log", [])
	balance_changed.emit(wallet)
