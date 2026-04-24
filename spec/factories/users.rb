FactoryBot.define do
  factory :user do
    sequence(:email_address) { |n| "user#{n}@example.com" }
    password { "password123" }

    trait :google_user do
      password { nil }
      sequence(:google_uid) { |n| "google-uid-#{n}" }
    end
  end

  factory :google_user, parent: :user, traits: [ :google_user ]
end
