namespace :user do
  task product_refactore: :environment do
    User.where(is_new: true).each do |user|
      UserRefactorJob.perform_later(user_id: user.id)
    end
  end
end
