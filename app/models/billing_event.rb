class BillingEvent < ApplicationRecord
  validates :provider, inclusion: { in: %w[paddle apple google] }
end
