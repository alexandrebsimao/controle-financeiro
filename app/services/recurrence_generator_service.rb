class RecurrenceGeneratorService
  def initialize(recurrence)
    @recurrence = recurrence
  end

  def call
    return 0 unless @recurrence.active?

    generated = 0

    while should_generate?
      Transaction.create!(
        user: @recurrence.user,
        bank_account: @recurrence.bank_account,
        category: @recurrence.category,
        recurrence: @recurrence,
        title: @recurrence.title,
        transaction_type: @recurrence.transaction_type,
        payment_method: @recurrence.payment_method,
        amount: @recurrence.amount,
        due_date: @recurrence.next_due_date,
        paid: false,
        recurrence_index: @recurrence.occurrences_generated + 1
      )

      @recurrence.increment!(:occurrences_generated)
      generated += 1

      if @recurrence.finished?
        @recurrence.update!(active: false)
        break
      end
    end

    generated
  end

  private

  def should_generate?
    return false if @recurrence.finished?
    next_date = @recurrence.next_due_date
    return false if next_date.nil?

    # Generate up to 3 months ahead
    next_date <= Date.today + 12.months
  end
end
