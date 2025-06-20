# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'
require 'dotenv'
require 'optparse'
require 'date'
require 'terminal-table'
require 'csv'
require 'digest'
require 'fileutils'
require 'zeitwerk'
require 'logger'

# Load environment variables from config directory
Dotenv.load('config/.env')

# Set up Zeitwerk autoloader
loader = Zeitwerk::Loader.for_gem
loader.logger = Logger.new($stdout) if ENV['ZEITWERK_DEBUG']
loader.setup

module KanbanMetrics
  class Error < StandardError; end
  class ApiError < Error; end
  class CacheError < Error; end
end
