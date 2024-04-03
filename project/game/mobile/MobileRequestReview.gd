class_name MobileRequestReview

const GOOGLE_SINGLETON := &"GodotGooglePlayInAppReview"
const APPLE_SINGLETON := &"RequestReview"
const OPTION_NAME := "deadline_for_next_review_request"

static var google_review = null
static var apple_review = null
static var enabled: bool:
	get: return google_review != null or apple_review != null
static var just_requested_review := false

static func _static_init() -> void:
	if Engine.has_singleton(GOOGLE_SINGLETON):
		google_review = Engine.get_singleton(GOOGLE_SINGLETON)
	elif Engine.has_singleton(APPLE_SINGLETON):
		apple_review = Engine.get_singleton(APPLE_SINGLETON)

static func maybe_request_review() -> void:
	just_requested_review = false
	if not enabled or Profile.get_option(OPTION_NAME) > Time.get_unix_time_from_system():
		return
	if not CampaignLevelLister.section_complete(3):
		# Too soon for a review
		return
	# Regardless of success or failure, let's reschedule the next review request
	Profile.set_option(OPTION_NAME, Time.get_unix_time_from_system() + randf_range(10., 20.) * 24 * 60 * 60, true)
	just_requested_review = true
	print("Requesting user review")
	if google_review != null:
		google_review.requestReviewInfo()
		await google_review.on_request_review_success
		# Then do the actual review
		print("Successfully got review info")
		google_review.launchReviewFlow()
		await google_review.on_launch_review_flow_success
	elif apple_review != null:
		apple_review.requestReview()
