class Photo < ApplicationRecord
  belongs_to :dressmaker_profile, dependent: :destroy
  has_many :specialities, through: :dressmaker_profile
  mount_uploader :url, PhotoUploader
  # validates :url, presence: true
end
