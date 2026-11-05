class AutoCategorizationService
  def initialize(title, user)
    @title = title.to_s.downcase.strip
    @user = user
  end

  def call
    keywords = CategoryKeyword
      .joins(:category)
      .where(categories: { user_id: [nil, @user.id] })
      .order(priority: :desc)

    keywords.each do |keyword|
      return keyword.category if keyword.matches?(@title)
    end

    nil
  end
end
