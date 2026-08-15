require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module HelixKit
  class Application < Rails::Application

    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
    #
    ## Disable unnecessary files when generating
    # Ensure new RubyLLM ActsAs API (with model:, model_class: kwargs) is
    # included in ActiveRecord::Base before models are eager-loaded, regardless
    # of when the RubyLLM Railtie's on_load(:active_record) fires relative to
    # the config/initializers/00_ruby_llm.rb that sets use_new_acts_as = true.
    config.to_prepare do
      require "ruby_llm/active_record/acts_as"
      unless ActiveRecord::Base.ancestors.include?(RubyLLM::ActiveRecord::ActsAs)
        ActiveRecord::Base.include RubyLLM::ActiveRecord::ActsAs
      end
    end

    config.generators do |g|
      g.helper false               # No helper files
      g.assets false               # No CSS/JS assets
      g.view_specs false           # No view tests
      g.helper_specs false         # No helper tests
      g.routing_specs false        # No routing tests
      g.test_framework nil         # No test framework
      g.fixture_replacement nil    # No fixtures
      g.template_engine nil        # No views/templates
    end

  end
end
