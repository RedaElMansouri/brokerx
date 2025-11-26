# frozen_string_literal: true

class MfaCode < ApplicationRecord
  belongs_to :client

  validates :code, presence: true, length: { is: 6 }
  validates :expires_at, presence: true

  scope :active, -> { where(used: false).where('expires_at > ?', Time.current) }

  def expired?
    expires_at < Time.current
  end

  def valid_code?
    !used? && !expired?
  end

  def mark_as_used!
    update!(used: true, used_at: Time.current)
  end
end
