# frozen_string_literal: true

require 'active_support/all'

FactoryBot.define do
  factory :linear_issue, class: Hash do
    skip_create

    title { Faker::Lorem.sentence }
    state { association :linear_state }
    team { association :linear_team }
    assignee { association :linear_user }
    createdAt do
      Faker::Time.between(from: 3.months.ago, to: 1.month.ago).iso8601
    end
    updatedAt { Faker::Time.between(from: 1.month.ago, to: Time.now).iso8601 }
    priority { [1, 2, 3, 4].sample }
    estimate { [1, 2, 3, 5, 8].sample }

    trait :completed do
      completedAt { Faker::Time.between(from: 1.month.ago, to: Time.now).iso8601 }
      state { association :linear_state, :completed }
    end

    trait :in_progress do
      startedAt { Faker::Time.between(from: 2.weeks.ago, to: 1.week.ago).iso8601 }
      state { association :linear_state, :in_progress }
    end

    trait :backlog do
      state { association :linear_state, :backlog }
    end

    trait :archived do
      archivedAt { Faker::Time.between(from: 1.week.ago, to: Time.now).iso8601 }
    end

    initialize_with { attributes.stringify_keys }
  end

  factory :linear_state, class: Hash do
    skip_create

    name { 'Todo' }
    type { 'backlog' }

    trait :completed do
      name { 'Done' }
      type { 'completed' }
    end

    trait :in_progress do
      name { 'In Progress' }
      type { 'started' }
    end

    trait :backlog do
      name { 'Todo' }
      type { 'backlog' }
    end

    initialize_with { attributes.stringify_keys }
  end

  factory :linear_team, class: Hash do
    skip_create

    name { Faker::Team.name }
    key { Faker::Lorem.characters(number: 3).upcase }

    initialize_with { attributes.stringify_keys }
  end

  factory :linear_user, class: Hash do
    skip_create

    name { Faker::Name.name }
    email { Faker::Internet.email }

    initialize_with { attributes.stringify_keys }
  end

  factory :linear_api_response, class: Hash do
    skip_create

    data do
      {
        'issues' => {
          'nodes' => build_list(:linear_issue, 5),
          'pageInfo' => {
            'hasNextPage' => false,
            'endCursor' => nil
          }
        }
      }
    end

    trait :with_pagination do
      data do
        {
          'issues' => {
            'nodes' => build_list(:linear_issue, 10),
            'pageInfo' => {
              'hasNextPage' => true,
              'endCursor' => 'cursor-123'
            }
          }
        }
      end
    end

    trait :with_completed_issues do
      data do
        {
          'issues' => {
            'nodes' => build_list(:linear_issue, 5, :completed),
            'pageInfo' => {
              'hasNextPage' => false,
              'endCursor' => nil
            }
          }
        }
      end
    end

    initialize_with { attributes }
  end
end
