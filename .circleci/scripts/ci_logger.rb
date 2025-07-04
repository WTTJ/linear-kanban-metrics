# frozen_string_literal: true

# CI Logger Module
# Provides consistent logging functionality for CI scripts
#
# Usage examples:
#   require_relative 'ci_logger'
#
#   CILogger.info('General information')
#   CILogger.success('Operation completed successfully')
#   CILogger.warning('Warning message')
#   CILogger.error('Error message')
#   CILogger.section('Section Title')
#   CILogger.stat('Label', value, good: true)
#   CILogger.indent('Indented message')
#
# Environment variables:
#   CI_DEBUG=true or DEBUG=true - Enable debug messages

module CILogger
  # ANSI color codes for console output
  COLORS = {
    reset: "\e[0m",
    red: "\e[31m",
    green: "\e[32m",
    yellow: "\e[33m",
    blue: "\e[34m",
    magenta: "\e[35m",
    cyan: "\e[36m",
    bold: "\e[1m"
  }.freeze

  # Log level constants
  LOG_LEVELS = {
    info: 'INFO',
    success: 'SUCCESS',
    warning: 'WARNING',
    error: 'ERROR',
    debug: 'DEBUG'
  }.freeze

  class << self
    # Main logging method with level and color support
    def log(message, level: :info, color: nil)
      timestamp = Time.now.strftime('%H:%M:%S')
      level_text = LOG_LEVELS[level] || 'INFO'

      colored_message = color ? colorize(message, color) : message

      puts "[#{timestamp}] #{level_text}: #{colored_message}"
    end

    # Convenience methods for different log levels
    def info(message)
      log(message, level: :info, color: :blue)
    end

    def success(message)
      log("✅ #{message}", level: :success, color: :green)
    end

    def warning(message)
      log("⚠️  #{message}", level: :warning, color: :yellow)
    end

    def error(message)
      log("❌ #{message}", level: :error, color: :red)
    end

    def debug(message)
      log(message, level: :debug, color: :magenta) if debug_enabled?
    end

    # Section headers for better organization
    def section(title)
      puts
      puts colorize("=== #{title} ===", :bold)
      puts
    end

    # Progress indicators
    def step(message)
      log(message, color: :cyan)
    end

    # Summary reporting
    def summary(title, &_block)
      section(title)
      yield if block_given?
      puts
    end

    # File/directory operations
    def file_operation(operation, path)
      info("#{operation}: #{path}")
    end

    # Command execution logging
    def command(cmd, success: true)
      if success
        success("Command completed: #{cmd}")
      else
        warning("Command failed: #{cmd}")
      end
    end

    # Statistics display
    def stat(label, value, good: nil)
      color = case good
              when true then :green
              when false then :red
              else :reset
              end

      puts colorize("#{label}: #{value}", color)
    end

    # Progress with indentation
    def indent(message, level: 1)
      indentation = '  ' * level
      puts "#{indentation}#{message}"
    end

    private

    def colorize(text, color)
      return text unless color && COLORS[color]

      "#{COLORS[color]}#{text}#{COLORS[:reset]}"
    end

    def debug_enabled?
      ENV['CI_DEBUG'] == 'true' || ENV['DEBUG'] == 'true'
    end
  end
end
