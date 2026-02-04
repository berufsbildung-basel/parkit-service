# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BillingRunner do
  let(:parking_spot) { ParkingSpot.create!(number: 1) }
  let(:cashctrl_client) { instance_double(CashctrlClient) }

  # Use a date in the past for billing (last month)
  let(:period_start) { 1.month.ago.beginning_of_month.to_date }
  let(:period_end) { 1.month.ago.end_of_month.to_date }
  let(:reservation_date) { period_start + 10.days } # Mid-month in past

  before do
    allow(CashctrlClient).to receive(:new).and_return(cashctrl_client)
    allow(Rails.application.config).to receive(:cashctrl).and_return({
                                                                       billing_start_date: 1.year.ago.to_date,
                                                                       invoice_category_id: 1,
                                                                       sales_account_id: 176,
                                                                       tax_id: 1,
                                                                       artikel: {
                                                                         car_halfday_weekday: 'PARK-CAR-HD-WD',
                                                                         car_halfday_weekend: 'PARK-CAR-HD-WE',
                                                                         car_fullday_weekday: 'PARK-CAR-FD-WD',
                                                                         car_fullday_weekend: 'PARK-CAR-FD-WE',
                                                                         motorcycle_halfday_weekday: 'PARK-MC-HD-WD',
                                                                         motorcycle_halfday_weekend: 'PARK-MC-HD-WE',
                                                                         motorcycle_fullday_weekday: 'PARK-MC-FD-WD',
                                                                         motorcycle_fullday_weekend: 'PARK-MC-FD-WE'
                                                                       }
                                                                     })
  end

  describe 'standard users' do
    let(:standard_user) do
      User.create!(username: 'standard', email: 'standard@example.com', first_name: 'Standard', last_name: 'User',
                   billing_type: :standard)
    end
    let(:standard_vehicle) do
      Vehicle.create!(user: standard_user, license_plate_number: 'ZH 123', make: 'VW', model: 'Golf')
    end

    before do
      # Create reservation in past (bypass validation by setting date directly after create)
      reservation = Reservation.new(
        user: standard_user,
        vehicle: standard_vehicle,
        parking_spot: parking_spot,
        date: Date.tomorrow,
        half_day: false
      )
      reservation.save!
      reservation.update_column(:date, reservation_date)

      allow(cashctrl_client).to receive(:find_or_create_person).and_return(123)
      allow(cashctrl_client).to receive(:create_invoice).and_return(456)
    end

    it 'creates invoice for standard user' do
      runner = described_class.new(period_start, period_end)
      result = runner.run

      expect(result[:standard][:created]).to eq(1)
      expect(Invoice.count).to eq(1)
    end

    it 'stores cashctrl references on invoice' do
      runner = described_class.new(period_start, period_end)
      runner.run

      invoice = Invoice.last
      expect(invoice.cashctrl_person_id).to eq(123)
      expect(invoice.cashctrl_invoice_id).to eq(456)
    end

    it 'creates line items for invoice' do
      runner = described_class.new(period_start, period_end)
      runner.run

      expect(InvoiceLineItem.count).to eq(1)
    end

    it 'skips already invoiced users' do
      Invoice.create!(
        user: standard_user,
        cashctrl_person_id: 123,
        period_start: period_start,
        period_end: period_end
      )

      runner = described_class.new(period_start, period_end)
      result = runner.run

      expect(result[:standard][:skipped]).to eq(1)
      expect(result[:standard][:created]).to eq(0)
    end
  end

  describe 'prepaid users' do
    let(:prepaid_user) do
      User.create!(
        username: 'prepaid',
        email: 'prepaid@example.com',
        first_name: 'Prepaid',
        last_name: 'User',
        billing_type: :prepaid,
        cashctrl_private_account_id: 200,
        prepaid_threshold: 100,
        prepaid_topup_amount: 500
      )
    end
    let(:prepaid_vehicle) do
      Vehicle.create!(user: prepaid_user, license_plate_number: 'ZH 456', make: 'BMW', model: '3')
    end

    before do
      reservation = Reservation.new(
        user: prepaid_user,
        vehicle: prepaid_vehicle,
        parking_spot: parking_spot,
        date: Date.tomorrow,
        half_day: false
      )
      reservation.save!
      reservation.update_column(:date, reservation_date)

      allow(cashctrl_client).to receive(:find_or_create_person).and_return(789)
      allow(cashctrl_client).to receive(:create_journal_entry).and_return(999)
      allow(cashctrl_client).to receive(:get_account_balance).and_return(350.0) # Above threshold
    end

    it 'creates journal entry for prepaid user' do
      runner = described_class.new(period_start, period_end)
      result = runner.run

      expect(result[:prepaid][:journal_entries_created]).to eq(1)
      expect(JournalEntry.count).to eq(1)
    end

    it 'does not create top-up invoice when balance above threshold' do
      allow(cashctrl_client).to receive(:get_account_balance).and_return(350.0)

      runner = described_class.new(period_start, period_end)
      result = runner.run

      expect(result[:prepaid][:topup_invoices_created]).to eq(0)
    end

    it 'creates top-up invoice when balance below threshold' do
      allow(cashctrl_client).to receive(:get_account_balance).and_return(50.0)
      allow(cashctrl_client).to receive(:create_custom_invoice).and_return(888)

      runner = described_class.new(period_start, period_end)
      result = runner.run

      expect(result[:prepaid][:topup_invoices_created]).to eq(1)
      expect(Invoice.count).to eq(1)
      expect(Invoice.last.total_amount).to eq(500) # prepaid_topup_amount
    end
  end

  describe 'exempt users' do
    let(:exempt_user) do
      User.create!(username: 'exempt', email: 'exempt@example.com', first_name: 'Exempt', last_name: 'User',
                   billing_type: :exempt)
    end
    let(:exempt_vehicle) do
      Vehicle.create!(user: exempt_user, license_plate_number: 'ZH 789', make: 'Audi', model: 'A4')
    end

    before do
      reservation = Reservation.new(
        user: exempt_user,
        vehicle: exempt_vehicle,
        parking_spot: parking_spot,
        date: Date.tomorrow,
        half_day: false
      )
      reservation.save!
      reservation.update_column(:date, reservation_date)
    end

    it 'skips exempt users' do
      runner = described_class.new(period_start, period_end)
      result = runner.run

      expect(result[:exempt][:skipped]).to eq(1)
      expect(Invoice.count).to eq(0)
      expect(JournalEntry.count).to eq(0)
    end
  end

  describe 'period validation' do
    it 'raises error for future period' do
      future_start = Date.today.beginning_of_month
      future_end = Date.today.end_of_month

      expect do
        described_class.new(future_start, future_end).run
      end.to raise_error(/Cannot bill current or future months/)
    end

    it 'raises error for period before billing start date' do
      allow(Rails.application.config).to receive(:cashctrl).and_return({
                                                                         billing_start_date: Date.today,
                                                                         revenue_account_id: 100
                                                                       })

      expect do
        described_class.new(period_start, period_end).run
      end.to raise_error(/Period is before billing start date/)
    end
  end
end
