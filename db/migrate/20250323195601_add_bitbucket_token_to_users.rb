class AddBitbucketTokenToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :bitbucket_token, :string
  end
end
