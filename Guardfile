# frozen_string_literal: true

# Guardfile for kanban-script gem
# Run `bundle exec guard` to start watching files

group :red_green_refactor, halt_on_fail: true do
  # RSpec Guard - Run tests automatically
  guard :rspec, cmd: 'bundle exec rspec' do
    # Watch all spec files
    watch(%r{^spec/.*_spec\.rb$})

    # Watch library files and trigger corresponding spec files
    watch(%r{^lib/(.+)\.rb$}) do |m|
      spec_file = "spec/lib/#{m[1]}_spec.rb"
      File.exist?(spec_file) ? spec_file : 'spec'
    end

    # Watch specific kanban_metrics library structure
    watch(%r{^lib/kanban_metrics/(.+)\.rb$}) do |m|
      spec_file = "spec/lib/#{m[1]}_spec.rb"
      File.exist?(spec_file) ? spec_file : 'spec'
    end

    # Run all specs if the spec_helper or support files change
    watch(%r{^spec/spec_helper\.rb$}) { 'spec' }
    watch(%r{^spec/support/.*\.rb$}) { 'spec' }

    # Watch main lib file to run integration tests
    watch('lib/kanban_metrics.rb') { 'spec/integration' }

    # Watch main gem files
    watch('lib/kanban_metrics/version.rb') { 'spec' }
    watch('kanban_metrics.gemspec') { 'spec' }
  end

  # RuboCop Guard - Run linting on specific file changes only
  guard :rubocop, all_on_start: false, keep_failed: false do
    # Watch only the files that are commonly edited
    watch(%r{^lib/kanban_metrics/.*\.rb$})
    watch(%r{^lib/kanban_metrics\.rb$})

    # Don't watch specs to avoid noise during TDD
    # watch(%r{^spec/.*\.rb$})

    # Watch configuration files
    watch('.rubocop.yml')
    watch('Gemfile')
    watch('kanban_metrics.gemspec')
  end
end
