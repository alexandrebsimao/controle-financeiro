class CategoryKeyword < ApplicationRecord
  belongs_to :category

  MATCH_TYPES = %w[contains starts_with exact].freeze

  validates :keyword, presence: true
  validates :match_type, inclusion: { in: MATCH_TYPES }

  def matches?(title)
    normalized_title = title.downcase.strip
    normalized_keyword = keyword.downcase.strip

    case match_type
    when "exact"
      normalized_title == normalized_keyword
    when "starts_with"
      normalized_title.start_with?(normalized_keyword)
    when "contains"
      normalized_title.include?(normalized_keyword)
    else
      false
    end
  end
end
