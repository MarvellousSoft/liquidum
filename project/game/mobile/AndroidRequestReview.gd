class_name AndroidRequestReview

const SINGLETON_NAME := &"GodotGooglePlayInAppReview"
const OPTION_NAME := "deadline_for_next_review_request"

static var in_app_review = null
static var enabled: bool:
	get: return in_app_review != null
static var just_requested_review := false

static func _static_init() -> void:
	if Engine.has_singleton(SINGLETON_NAME):
		in_app_review = Engine.get_singleton(SINGLETON_NAME)

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
	var in_app_review = Engine.get_singleton(SINGLETON_NAME)
	in_app_review.requestReviewInfo()
	await in_app_review.on_request_review_success
	# Then do the actual review
	print("Requesting user review")
	in_app_review.launchReviewFlow()
	await in_app_review.on_launch_review_flow_success
