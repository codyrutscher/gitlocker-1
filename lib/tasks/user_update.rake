namespace :old do
  task user_update: :environment do
    User.update_all(is_new: false)
  end
end
