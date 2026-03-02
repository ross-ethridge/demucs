require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Web
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

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

    config.demucs_input_path  = ENV.fetch("DEMUCS_INPUT_PATH",  Rails.root.join("..", "input").to_s)
    config.demucs_output_path = ENV.fetch("DEMUCS_OUTPUT_PATH", Rails.root.join("..", "output").to_s)
    config.demucs_models_path = ENV.fetch("DEMUCS_MODELS_PATH", Rails.root.join("..", "models").to_s)
    config.demucs_image       = ENV.fetch("DEMUCS_IMAGE",       "xserrat/facebook-demucs:latest")
  end
end
