# frozen_string_literal: true

require 'factory_bot'

# FactoryBot Configuration
RSpec.configure do |config|
  # Include FactoryBot methods in all specs
  config.include FactoryBot::Syntax::Methods

  # Load factory definitions before suite runs
  config.before(:suite) do
    FactoryBot.find_definitions
  end

  # Optional: Lint factories to ensure they're valid
  config.before(:suite) do
    FactoryBot.lint if ENV['FACTORY_BOT_LINT'] == 'true'
  end
end
