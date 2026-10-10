class Feature < ApplicationRecord
  validates :key, presence: true, uniqueness: true

  def self.admin_only?(key)
    find_by(key: key)&.admin_only != false
  end
end
