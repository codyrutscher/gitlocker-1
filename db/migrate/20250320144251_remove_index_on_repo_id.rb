class RemoveIndexOnRepoId < ActiveRecord::Migration[7.1]
  def change
    remove_index :products, :repo_id
  end
end
