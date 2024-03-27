class_name AndroidRequestReview

const SINGLETON_NAME := &"GodotGooglePlayInAppReview"

static func enabled() -> bool:
    return Engine.has_singleton(SINGLETON_NAME)

static func request_review() -> void:
    if not enabled():
        return
    if not CampaignLevelLister.section_complete(3):
        # Too soon for a review
        return
    var in_app_review = Engine.get_singleton(SINGLETON_NAME)
    in_app_review.requestReviewInfo()
    await in_app_review.on_request_review_success
    # Regardless of success or failure, let's reschedule the next review request
    Profile.set_option("deadline_for_next_review_request", Time.get_unix_time_from_system() + randf_range(10., 20.) * 24 * 60 * 60, true)
    # Then do the actual review
    print("Requesting user review")
    in_app_review.launchReviewFlow()
    await in_app_review.on_launch_review_flow_success