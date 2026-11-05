class GenerateRecurrencesJob
  include Sidekiq::Job

  sidekiq_options retry: 3, dead: true

  def perform
    Recurrence.active.find_each do |recurrence|
      RecurrenceGeneratorService.new(recurrence).call
    end
  end
end
