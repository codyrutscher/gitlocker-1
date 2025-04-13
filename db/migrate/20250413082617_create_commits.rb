class CreateCommits < ActiveRecord::Migration[7.1]
  def change
    create_table :commits do |t|
      t.references :product, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :file_path
      t.string :uuid
      t.text :new_content
      t.text :old_content
      t.text :commit_message

      t.timestamps
    end
  end
end
