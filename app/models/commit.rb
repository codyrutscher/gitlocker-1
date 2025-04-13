class Commit < ApplicationRecord
  belongs_to :product
  belongs_to :user
  before_create :generate_unique_uuid

  private

  def generate_unique_uuid
    loop do
      self.uuid = SecureRandom.alphanumeric(6).downcase
      break unless Commit.exists?(uuid: uuid)
    end
  end
end
