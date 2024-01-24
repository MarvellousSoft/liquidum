class_name AndroidPayment
extends Node

const PURCHASE_NAME := "TODO"

var api

signal disable_ads()

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
	api = api_
	api.billing_resume.connect(_on_billing_resume)
	api.connected.connect(_on_connected)
	api.product_details_query_completed.connect(_on_product_details_query_completed)
	api.product_details_query_error.connect(_on_product_details_query_error)
	api.purchases_updated.connect(_on_purchases_updated)
	api.purchase_error.connect(_on_purchase_error)
	api.query_purchases_response.connect(_on_query_purchases_response)
	api.startConnection()

static func setup() -> AndroidPayment:
	if Engine.has_singleton("GodotGooglePlayBilling"):
		return AndroidPayment.new(Engine.get_singleton("GodotGooglePlayBilling"))
	else:
		print("Unavailable Android payments")
		return null

func _on_connected() -> void:
	api.querySkuDetails([PURCHASE_NAME], "inapp")

func _on_product_details_query_completed(product_details):
	for available_product in product_details:
		print("Product: %s" % available_product)

func _on_product_details_query_error(response_id, error_message, products_queried):
	print("Query err id: %s err %s products %s" % [response_id, error_message, products_queried])

func _on_billing_resume():
	if api.getConnectionState() == ConnectionState.CONNECTED:
		api.queryPurchases(PURCHASE_NAME)

func do_purchase() -> void:
	api.purchase(PURCHASE_NAME)

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
	if PURCHASE_NAME in purchase.products and purchase.purchase_state == PurchaseState.PURCHASED:
		disable_ads.emit()
		if not purchase.is_acknowledged:
			api.acknowledgePurchase(purchase.purchase_token)
