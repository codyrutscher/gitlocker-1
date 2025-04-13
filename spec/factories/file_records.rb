FactoryBot.define do
  factory :file_record do
    product { nil }
    user { nil }
    file_name { "MyString" }
    content { "MyText" }
  end
end
