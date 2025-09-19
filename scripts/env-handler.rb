#!/usr/bin/env ruby
# frozen_string_literal: true

# Generate .env file from 1Password template
# Usage: ruby scripts/env-handler.rb

require 'English'
require 'fileutils'
require 'json'
require 'tempfile'
require 'shellwords'

class EnvHandler
  # ANSI color codes
  GREEN = "\033[0;32m"
  YELLOW = "\033[1;33m"
  RED = "\033[0;31m"
  NC = "\033[0m" # No Color

  def initialize
    @script_dir = __dir__
    @project_dir = File.expand_path('..', @script_dir)
    @template_file = File.join(@project_dir, 'config', 'env.1password.template')
    @env_file = File.join(@project_dir, 'config', '.env')
    @backup_file = File.join(@project_dir, 'config', '.env.backup')
  end

  def run
    print_status('Starting .env generation from 1Password template...')

    validate_prerequisites
    validate_template_exists
    backup_existing_env
    generate_env_file
    validate_env_file

    print_success_message
  rescue StandardError => e
    print_error("Failed to generate .env file: #{e.message}")
    exit 1
  end

  private

  attr_reader :script_dir, :project_dir, :template_file, :env_file, :backup_file

  def print_status(message)
    puts "#{GREEN}[INFO]#{NC} #{message}"
  end

  def print_warning(message)
    puts "#{YELLOW}[WARN]#{NC} #{message}"
  end

  def print_error(message)
    puts "#{RED}[ERROR]#{NC} #{message}"
  end

  def validate_prerequisites
    validate_op_cli_installed
    validate_op_signed_in
  end

  def validate_op_cli_installed
    return if system('which op > /dev/null 2>&1')

    print_error('1Password CLI is not installed. Please install it first:')
    puts '  brew install --cask 1password/tap/1password-cli'
    exit 1
  end

  def validate_op_signed_in
    return if system('op account list > /dev/null 2>&1')

    print_error('Not signed in to 1Password. Please sign in first:')
    puts '  op signin'
    exit 1
  end

  def validate_template_exists
    return if File.exist?(template_file)

    print_error("Template file not found: #{template_file}")
    exit 1
  end

  def backup_existing_env
    return unless File.exist?(env_file)

    FileUtils.cp(env_file, backup_file)
    print_warning('Existing .env file backed up to .env.backup')
  end

  def generate_env_file
    print_status('Generating .env file from 1Password template...')

    Tempfile.create('env_temp') do |temp_file|
      process_template_lines(temp_file)
      FileUtils.mv(temp_file.path, env_file)
    end

    print_status('✓ .env file generated successfully!')
  end

  def process_template_lines(temp_file)
    File.foreach(template_file) do |line|
      line = line.chomp

      if comment_or_empty_line?(line)
        temp_file.puts(line)
        next
      end

      if onepassword_reference?(line)
        process_onepassword_line(line, temp_file)
      else
        temp_file.puts(line)
      end
    end
  end

  def comment_or_empty_line?(line)
    line.strip.empty? || line.strip.start_with?('#')
  end

  def onepassword_reference?(line)
    line.match?(%r{op://([^/]+)/([^/]+)/([^\s]+)})
  end

  def process_onepassword_line(line, temp_file)
    match = line.match(%r{op://([^/]+)/([^/]+)/([^\s]+)})
    return temp_file.puts(line) unless match

    vault, item, field = match.captures
    var_name = line.split('=').first

    print_status("Resolving #{var_name} from 1Password...")

    value = fetch_from_onepassword(item, vault, field)
    if value
      temp_file.puts("#{var_name}=#{value}")
      print_status("✓ Successfully resolved #{var_name}")
    else
      print_warning("Failed to resolve #{var_name} from 1Password. Adding placeholder...")
      temp_file.puts("#{var_name}=# FAILED_TO_RESOLVE: #{line.split('=', 2)[1]}")
    end
  end

  def fetch_from_onepassword(item, vault, field)
    command = ['op', 'item', 'get', item, '--vault', vault, '--field', field, '--reveal']
    result = `#{Shellwords.shelljoin(command)} 2>/dev/null`

    $CHILD_STATUS.success? ? result.strip : nil
  end

  def validate_env_file
    print_status('Validating .env file...')

    required_vars = ['LINEAR_API_TOKEN']
    conditional_vars = determine_conditional_vars

    missing_vars = check_missing_variables(required_vars + conditional_vars)

    if missing_vars.empty?
      print_status('✓ All required variables are present')
    else
      print_error('Missing or failed to resolve required variables:')
      missing_vars.each { |var| puts "  - #{var}" }
      puts
      puts 'Please check your 1Password vault and ensure the items exist with correct field names.'
      exit 1
    end
  end

  def determine_conditional_vars
    conditional_vars = []
    env_content = File.read(env_file)

    if env_content.match?(/^API_PROVIDER=anthropic/m)
      conditional_vars << 'ANTHROPIC_API_KEY'
    elsif env_content.match?(/^API_PROVIDER=dust/m)
      conditional_vars += %w[DUST_API_KEY DUST_WORKSPACE_ID DUST_AGENT_ID]
    end

    conditional_vars << 'GITHUB_TOKEN' if env_content.match?(/^GITHUB_REPOSITORY=.+/m) && !env_content.match?(/^GITHUB_REPOSITORY=$/m)

    conditional_vars
  end

  def check_missing_variables(vars_to_check)
    env_content = File.read(env_file)
    missing_vars = []

    vars_to_check.each do |var|
      unless env_content.match?(/^#{Regexp.escape(var)}=.+/m) &&
             !env_content.match?(/^#{Regexp.escape(var)}=.*FAILED_TO_RESOLVE/m)
        missing_vars << var
      end
    end

    missing_vars
  end

  def print_success_message
    puts
    puts '📋 Summary:'
    puts "  Template: #{File.basename(template_file)}"
    puts "  Output:   #{File.basename(env_file)}"
    puts "  Backup:   #{File.basename(backup_file)}" if File.exist?(backup_file)
    puts
    print_status('🚀 Ready to use! You can now run your application:')
    puts '  ./bin/kanban_metrics'
    puts '  bundle exec rspec'
  end
end

# Run the script if called directly
EnvHandler.new.run if __FILE__ == $PROGRAM_NAME
