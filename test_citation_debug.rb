#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'logger'
require 'stringio'

# Load the PR review script
$LOAD_PATH.unshift(File.join(__dir__, '.github', 'scripts'))
require_relative '.github/scripts/pr_review'

class CitationDebugTest
  include DustResponseProcessor

  attr_reader :logger

  def initialize
    @logger = Logger.new($stdout)
    @logger.level = Logger::DEBUG
  end

  def test_extraction_with_actions
    puts '=== Testing Citation Extraction with Actions Structure ==='

    # Test with Dust API structure (actions)
    dust_api_response = {
      'conversation' => {
        'content' => [
          [
            {
              'type' => 'agent_message',
              'status' => 'succeeded',
              'content' => 'This is a test :cite[aa,eu] with citations :cite[bb].',
              'actions' => [
                {
                  'type' => 'tool_action',
                  'output' => [
                    {
                      'type' => 'resource',
                      'resource' => {
                        'uri' => 'https://example.com/1',
                        'title' => 'Document 1',
                        'reference' => 'aa'
                      }
                    },
                    {
                      'type' => 'resource',
                      'resource' => {
                        'uri' => 'https://example.com/2',
                        'title' => 'Document 2',
                        'reference' => 'eu'
                      }
                    },
                    {
                      'type' => 'resource',
                      'resource' => {
                        'uri' => 'https://example.com/3',
                        'title' => 'Document 3',
                        'reference' => 'bb'
                      }
                    }
                  ]
                }
              ]
            }
          ]
        ]
      }
    }

    result = extract_content(dust_api_response)
    puts 'Result with actions structure:'
    puts result
    puts "\nCitation markers processed: #{result.include?(':cite[') ? 'NO ❌' : 'YES ✅'}"

    # Test with simple citations structure
    puts "\n=== Testing with Simple Citations Structure ==="

    simple_response = {
      'conversation' => {
        'content' => [
          [
            {
              'type' => 'agent_message',
              'status' => 'succeeded',
              'content' => 'This is a test :cite[aw,gx] with citations :cite[bt].',
              'citations' => [
                {
                  'id' => 'aw',
                  'reference' => {
                    'title' => 'Document A',
                    'href' => 'https://example.com/a'
                  }
                },
                {
                  'id' => 'gx',
                  'reference' => {
                    'title' => 'Document B',
                    'href' => 'https://example.com/b'
                  }
                },
                {
                  'id' => 'bt',
                  'reference' => {
                    'title' => 'Document C',
                    'href' => 'https://example.com/c'
                  }
                }
              ]
            }
          ]
        ]
      }
    }

    result2 = extract_content(simple_response)
    puts 'Result with simple citations structure:'
    puts result2
    puts "\nCitation markers processed: #{result2.include?(':cite[') ? 'NO ❌' : 'YES ✅'}"
  end
end

# Run the test
tester = CitationDebugTest.new
tester.test_extraction_with_actions
