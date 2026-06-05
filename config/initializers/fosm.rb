Fosm.configure do |config|
  # The base controller the FOSM engine inherits from
  config.base_controller = "ApplicationController"

  # Who can access /fosm/admin — site admins only
  config.admin_authorize = -> { redirect_to root_path unless Current.user&.site_admin }

  # How to authorize individual FOSM apps
  config.app_authorize = ->(_level) { authenticate_user! }

  # How to get the current user (for transition log actor tracking)
  config.current_user_method = -> { Current.user }

  # Layouts
  config.admin_layout = "application"
  config.app_layout   = "application"

  # Transition log write strategy — async via SolidQueue (non-blocking)
  config.transition_log_strategy = :async

  # Disable webhooks unless needed (reduces queue writes)
  config.webhooks_enabled = false
end
