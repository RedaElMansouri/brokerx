# frozen_string_literal: true

class Session < ApplicationRecord
  belongs_to :client

  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true

  scope :active, -> { where('expires_at > ?', Time.current).where(revoked: false) }

  before_validation :generate_token, on: :create

  def expired?
    expires_at < Time.current
  end

  def revoked?
    revoked
  end

  def valid_session?
    !expired? && !revoked?
  end

  def revoke!
    update!(revoked: true, revoked_at: Time.current)
  end

  private

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(32)
  end
end
