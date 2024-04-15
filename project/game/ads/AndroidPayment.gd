class_name AndroidPayment
extends PlatformPayment

const ADS_PURCHASE := "disable_ads"

var dlc_purchases := {}

var api

# Matches BillingClient.ConnectionState in the Play Billing Library
enum ConnectionState {
	DISCONNECTED, # not yet connected to billing service or was already closed
	CONNECTING, # currently in process of connecting to billing service
	CONNECTED, # currently connected to billing service
	CLOSED, # already closed and shouldn't be used again
}

# Matches Purchase.PurchaseState in the Play Billing Library
enum PurchaseState {
	UNSPECIFIED,
	PURCHASED,
	PENDING,
}

func _init(api_) -> void:
	super()
	api = api_
	api.billing_resume.connect(_on_billing_resume)
	api.connected.connect(_on_connected)
	api.disconnected.connect(_on_disconnected)
	api.connect_error.connect(_on_connect_error)
	api.sku_details_query_completed.connect(_on_sku_details_query_completed)
	api.sku_details_query_error.connect(_on_sku_details_query_error)
	api.purchases_updated.connect(_on_purchases_updated)
	api.purchase_error.connect(_on_purchase_error)
	api.query_purchases_response.connect(_on_query_purchases_response)

func start() -> void:
	api.startConnection()

static func setup() -> AndroidPayment:
	if Engine.has_singleton("GodotGooglePlayBilling"):
		return AndroidPayment.new(Engine.get_singleton("GodotGooglePlayBilling"))
	else:
		print("Unavailable Android payments")
		return null

func _on_connected() -> void:
	print("Connected to Android Payments")
	var section := 1
	while ExtraLevelLister.has_section(section):
		var payment_name := ExtraLevelLister.android_payment(section)
		if payment_name != "":
			dlc_purchases[payment_name] = true
		section += 1
	api.querySkuDetails(dlc_purchases.keys() + [ADS_PURCHASE], "inapp")

func _on_disconnected() -> void:
	print("Disconnected Android payments")

func _on_connect_error(id, err):
	push_error("Failed to connect: id %s err %s" % [id, err])

func _on_sku_details_query_completed(sku_details):
	for available_product in sku_details:
		print("Product: %s" % [available_product])
	# First time query purchase
	api.queryPurchases("inapp")

func _on_sku_details_query_error(response_id, error_message, products_queried):
	print("Query err id: %s err %s products %s" % [response_id, error_message, products_queried])

func _on_billing_resume():
	if api.getConnectionState() == ConnectionState.CONNECTED:
		api.queryPurchases("inapp")

func do_purchase_disable_ads() -> void:
	api.purchase(ADS_PURCHASE)

func do_purchase_dlc(payment_id: String) -> void:
	api.purchase(payment_id)

func _on_query_purchases_response(query_result):
	if query_result.status == OK:
		for purchase in query_result.purchases:
			_process_purchase(purchase)
	else:
		print("queryPurchases failed, code: %s msg: %s" % [query_result.response_code, query_result.debug_message])

func _on_purchases_updated(purchases):
	for purchase in purchases:
		_process_purchase(purchase)

func _on_purchase_error(response_id, error_message):
	print("Purchase error id: %s msg: %s" % [response_id, error_message])

func _process_purchase(purchase):
	print("Processing purchase: %s" % [purchase])
	if ADS_PURCHASE in purchase.skus and purchase.purchase_state == PurchaseState.PURCHASED:
		print("Did purchase remove ads")
		disable_ads.emit()
		if not purchase.is_acknowledged:
			api.acknowledgePurchase(purchase.purchase_token)
	for sku in purchase.skus:
		if purchase.purchase_state == PurchaseState.PURCHASED and dlc_purchases.has(sku):
			dlc_purchased.emit(sku)
			if not purchase.is_acknowledged:
				api.acknowledgePurchase(purchase.purchase_token)
