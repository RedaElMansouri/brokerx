# frozen_string_literal: true

class VerificationToken < ApplicationRecord
  belongs_to :client

  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true
  validates :token_type, presence: true, inclusion: { in: %w[email_verification password_reset] }

  scope :active, -> { where(used: false).where('expires_at > ?', Time.current) }
  scope :email_verification, -> { where(token_type: 'email_verification') }
  scope :password_reset, -> { where(token_type: 'password_reset') }

  def expired?
    expires_at < Time.current
  end

  def valid_token?
    !used? && !expired?
  end

  def mark_as_used!
    update!(used: true, used_at: Time.current)
  end
end
