FactoryGirl.define do
  factory :user, class: User do
    sequence(:username) { |n| "testuser#{n}" }
    sequence(:email) { |n| "testuser#{n}@example.com" }
    department "Test Department"

    trait :admin do
      roles ['admin']
    end
  end
end