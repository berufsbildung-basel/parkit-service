# frozen_string_literal: true

class BillingRunner
  JOURNAL_DESCRIPTIONS = {
    'de' => 'Parkgebühren %B %Y',
    'en' => 'Parking fees %B %Y',
    'fr' => 'Frais de parking %B %Y',
    'it' => 'Spese parcheggio %B %Y'
  }.freeze

  TOPUP_DESCRIPTIONS = {
    'de' => 'Aufladung Parkkonto',
    'en' => 'Parking account top-up',
    'fr' => 'Rechargement compte parking',
    'it' => 'Ricarica conto parcheggio'
  }.freeze

  def initialize(period_start, period_end, executed_by: nil)
    @period_start = period_start
    @period_end = period_end
    @executed_by = executed_by
    @client = CashctrlClient.new
    @results = {
      standard: { created: 0, skipped: 0 },
      prepaid: { created: 0, skipped: 0 },
      exempt: { skipped: 0 },
      errors: []
    }
  end

  def run
    validate_period!
    @billing_period = find_or_create_billing_period!

    process_standard_users
    process_prepaid_users
    process_exempt_users

    finalize_billing_period!
    @results
  end

  def preview
    {
      standard: preview_standard_users,
      prepaid: preview_prepaid_users,
      exempt: preview_exempt_users
    }
  end

  private

  def validate_period!
    billing_start = Rails.application.config.cashctrl[:billing_start_date]
    raise 'Period is before billing start date' if billing_start && @period_start < billing_start
    raise 'Cannot bill current or future months' if @period_end >= Date.today.beginning_of_month
  end

  def users_with_reservations
    User.joins(:reservations)
        .where(reservations: { date: @period_start..@period_end })
        .distinct
  end

  def user_reservations(user)
    user.reservations.where(date: @period_start..@period_end)
  end

  def user_total(user)
    user_reservations(user).where(cancelled: false).sum(:price)
  end

  # === Standard Users ===

  def process_standard_users
    users_with_reservations.standard_billing.find_each do |user|
      process_standard_user(user)
    rescue StandardError => e
      @results[:errors] << { user_id: user.id, type: :standard, error: e.message }
    end
  end

  def process_standard_user(user)
    if Invoice.exists?(user: user, period_start: @period_start) || user_total(user) <= 0
      @results[:standard][:skipped] += 1
      return
    end

    person_id = ensure_cashctrl_person(user)
    reservations = user_reservations(user)
    language = user.preferred_language || 'de'

    items = build_line_items(reservations, language)

    # Only include non-cancelled items with valid artikel_nr
    billable_items = items.select { |i| i[:artikel_nr].present? }

    cashctrl_invoice_id = @client.create_invoice(
      person_id: person_id,
      date: Date.today,
      due_days: 30,
      items: billable_items.map do |i|
        { artikel_nr: i[:artikel_nr], name: i[:description], unit_price: i[:unit_price], quantity: 1 }
      end,
      custom_fields: billing_period_custom_fields(language)
    )

    # Calculate total from reservations (CashCtrl has the prices)
    total = reservations.where(cancelled: false).sum(:price)

    invoice = Invoice.create!(
      user: user,
      cashctrl_person_id: person_id,
      cashctrl_invoice_id: cashctrl_invoice_id,
      period_start: @period_start,
      period_end: @period_end,
      total_amount: total,
      status: :draft
    )

    create_local_line_items(invoice, items)
    @results[:standard][:created] += 1
  end

  def preview_standard_users
    users_with_reservations.standard_billing
                           .where.not(id: Invoice.where(period_start: @period_start).pluck(:user_id))
                           .order(:email)
                           .map { |u| { user: u, total: user_total(u), reservations: user_reservations(u).count } }
                           .select { |p| p[:total] > 0 }
  end

  # === Prepaid Users ===

  def process_prepaid_users
    users_with_reservations.prepaid_billing.find_each do |user|
      process_prepaid_user(user)
    rescue StandardError => e
      @results[:errors] << { user_id: user.id, type: :prepaid, error: e.message }
    end
  end

  def process_prepaid_user(user)
    if Invoice.exists?(user: user, period_start: @period_start)
      @results[:prepaid][:skipped] += 1
      return
    end

    person_id = ensure_cashctrl_person(user)
    reservations = user_reservations(user)
    language = user.preferred_language || 'de'

    # Resolve CashCtrl account and fetch balance
    cashctrl_account_id = @client.resolve_account_id(user.cashctrl_private_account_id)
    balance = @client.get_account_balance(user.cashctrl_private_account_id)
    opening_amount = -balance # Invert: CashCtrl negative becomes positive on invoice

    # Build booking line items
    items = build_line_items(reservations, language)
    billable_items = items.select { |i| i[:artikel_nr].present? }

    # Skip if no balance and no bookings
    booking_total = reservations.where(cancelled: false).sum(:price)
    return if opening_amount == 0 && booking_total <= 0

    # Build CashCtrl invoice: opening balance line + booking lines
    balance_label = language == 'de' ? "Vortrag per #{@period_start.strftime('%d.%m.%Y')}" :
                                       "Balance carried forward #{@period_start.strftime('%d.%m.%Y')}"
    cashctrl_items = [
      { name: balance_label, unit_price: opening_amount, quantity: 1 }
    ] + billable_items.map do |i|
      { artikel_nr: i[:artikel_nr], name: i[:description], unit_price: i[:unit_price], quantity: 1 }
    end

    cashctrl_invoice_id = @client.create_invoice(
      person_id: person_id,
      date: Date.today,
      due_days: 30,
      items: cashctrl_items,
      custom_fields: billing_period_custom_fields(language),
      account_id: cashctrl_account_id
    )

    total = opening_amount + booking_total
    invoice = Invoice.create!(
      user: user,
      cashctrl_person_id: person_id,
      cashctrl_invoice_id: cashctrl_invoice_id,
      period_start: @period_start,
      period_end: @period_end,
      total_amount: total,
      status: :draft
    )

    # Opening balance line (no reservation)
    InvoiceLineItem.create!(
      invoice: invoice,
      description: balance_label,
      unit_price: opening_amount
    )
    create_local_line_items(invoice, items)

    @results[:prepaid][:created] += 1
  end

  def preview_prepaid_users
    users_with_reservations.prepaid_billing
                           .where.not(id: Invoice.where(period_start: @period_start).pluck(:user_id))
                           .order(:email)
                           .map { |u| { user: u, total: user_total(u), reservations: user_reservations(u).count } }
  end

  # === Exempt Users ===

  def process_exempt_users
    count = users_with_reservations.exempt_billing.count
    @results[:exempt][:skipped] = count
  end

  def preview_exempt_users
    users_with_reservations.exempt_billing
                           .order(:email)
                           .map { |u| { user: u, total: user_total(u), reservations: user_reservations(u).count } }
  end

  # === Helpers ===

  def ensure_cashctrl_person(user)
    return user.cashctrl_person_id if user.cashctrl_person_id

    person_id = @client.find_or_create_person(user)
    user.update!(cashctrl_person_id: person_id)
    person_id
  end

  def build_line_items(reservations, language)
    reservations.map do |reservation|
      builder = InvoiceLineItemBuilder.new(reservation, language)
      {
        reservation: reservation,
        description: builder.build_description,
        unit_price: builder.unit_price,
        artikel_nr: builder.artikel_nr
      }
    end
  end

  def create_local_line_items(invoice, items)
    items.each do |item|
      InvoiceLineItem.create!(
        invoice: invoice,
        reservation: item[:reservation],
        description: item[:description],
        unit_price: item[:unit_price]
      )
    end
  end

  def journal_entry_description(language)
    template = JOURNAL_DESCRIPTIONS[language] || JOURNAL_DESCRIPTIONS['de']
    @period_start.strftime(template)
  end

  def topup_line_item_description(language)
    TOPUP_DESCRIPTIONS[language] || TOPUP_DESCRIPTIONS['de']
  end

  def billing_period_custom_fields(language)
    field_id = Rails.application.config.cashctrl[:billing_period_field_id]
    return {} unless field_id.present?

    { field_id => billing_period_label(language) }
  end

  def billing_period_label(language)
    # Format: "January 2026" in user's language
    I18n.with_locale(language) do
      I18n.l(@period_start, format: '%B %Y')
    end
  end

  def find_or_create_billing_period!
    bp = BillingPeriod.find_or_initialize_by(period_start: @period_start)
    bp.update!(
      period_end: @period_end,
      status: :in_progress,
      executed_by: @executed_by,
      invoices_created: 0,
      invoices_skipped: 0,
      journal_entries_created: 0,
      topup_invoices_created: 0,
      exempt_skipped: 0,
      errors_log: []
    )
    bp
  end

  def finalize_billing_period!
    @billing_period.update!(
      status: @results[:errors].empty? ? :completed : :partially_failed,
      invoices_created: @results[:standard][:created] + @results[:prepaid][:created],
      invoices_skipped: @results[:standard][:skipped] + @results[:prepaid][:skipped],
      journal_entries_created: 0,
      topup_invoices_created: 0,
      exempt_skipped: @results[:exempt][:skipped],
      errors_log: @results[:errors],
      executed_at: Time.current
    )
  end
end
