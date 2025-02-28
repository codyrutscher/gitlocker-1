class AddGitlabTokenToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :gitlab_token, :string
  end
end
