# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/kanban_metrics/version'

RSpec.describe 'KanbanMetrics::VERSION' do
  subject { KanbanMetrics::VERSION }

  it 'has a version number' do
    expect(subject).not_to be_nil
  end

  it 'is a string' do
    expect(subject).to be_a(String)
  end

  it 'follows semantic versioning format' do
    expect(subject).to match(/\A\d+\.\d+\.\d+\z/)
  end

  it 'has the expected version' do
    expect(subject).to eq('1.0.0')
  end
end
