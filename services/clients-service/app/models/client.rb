# frozen_string_literal: true

# Client Entity - Core domain model for the Clients Service
# Handles UC-01 (Inscription & Vérification) and UC-02 (Authentification MFA)
class Client < ApplicationRecord
  has_secure_password

  # Associations
  has_many :verification_tokens, dependent: :destroy
  has_many :mfa_codes, dependent: :destroy
  has_many :sessions, dependent: :destroy

  # Validations
  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :password, length: { minimum: 8 }, if: :password_required?

  # Callbacks
  before_save :downcase_email
  after_create :send_verification_email

  # Scopes
  scope :verified, -> { where(email_verified: true) }
  scope :unverified, -> { where(email_verified: false) }
  scope :mfa_enabled, -> { where(mfa_enabled: true) }

  # Business Logic

  def verified?
    email_verified?
  end

  def verify_email!
    update!(email_verified: true, email_verified_at: Time.current)
    enable_mfa! unless mfa_enabled?
  end

  def enable_mfa!
    update!(mfa_enabled: true)
  end

  def generate_mfa_code!
    # Invalidate existing codes
    mfa_codes.active.update_all(used: true)

    # Generate new 6-digit code
    code = SecureRandom.random_number(100_000..999_999).to_s
    mfa_codes.create!(
      code: code,
      expires_at: 5.minutes.from_now
    )
  end

  def verify_mfa_code!(code)
    mfa_record = mfa_codes.active.find_by(code: code)
    return false unless mfa_record
    return false if mfa_record.expired?

    mfa_record.mark_as_used!
    true
  end

  def can_login?
    verified? && !locked?
  end

  def locked?
    locked_at.present? && locked_at > 30.minutes.ago
  end

  def lock!
    update!(locked_at: Time.current, failed_attempts: 0)
  end

  def unlock!
    update!(locked_at: nil, failed_attempts: 0)
  end

  def increment_failed_attempts!
    new_count = (failed_attempts || 0) + 1
    if new_count >= 5
      lock!
    else
      update!(failed_attempts: new_count)
    end
  end

  def reset_failed_attempts!
    update!(failed_attempts: 0)
  end

  private

  def downcase_email
    self.email = email.downcase.strip
  end

  def password_required?
    new_record? || password.present?
  end

  def send_verification_email
    token = verification_tokens.create!(
      token: SecureRandom.urlsafe_base64(32),
      expires_at: 24.hours.from_now,
      token_type: 'email_verification'
    )
    VerificationMailer.verification_email(self, token.token).deliver_later
  end
end
