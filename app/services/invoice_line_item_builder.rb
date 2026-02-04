# frozen_string_literal: true

class InvoiceLineItemBuilder
  TRANSLATIONS = {
    'de' => { spot: 'Platz', full_day: 'Ganztag', half_day_am: 'Vormittag', half_day_pm: 'Nachmittag',
              car: 'Auto', motorcycle: 'Motorrad', cancelled: 'Storniert' },
    'en' => { spot: 'Spot', full_day: 'Full day', half_day_am: 'Morning', half_day_pm: 'Afternoon',
              car: 'Car', motorcycle: 'Motorcycle', cancelled: 'Cancelled' },
    'fr' => { spot: 'Place', full_day: 'Journée', half_day_am: 'Matin', half_day_pm: 'Après-midi',
              car: 'Voiture', motorcycle: 'Moto', cancelled: 'Annulé' },
    'it' => { spot: 'Posto', full_day: 'Giornata', half_day_am: 'Mattina', half_day_pm: 'Pomeriggio',
              car: 'Auto', motorcycle: 'Moto', cancelled: 'Annullato' }
  }.freeze

  def initialize(reservation, language = 'de')
    @reservation = reservation
    @language = language
    @t = TRANSLATIONS[language] || TRANSLATIONS['de']
  end

  def build_description
    parts = [
      @reservation.date.strftime('%d.%m.%Y'),
      "#{@t[:spot]} ##{@reservation.parking_spot.number}",
      time_slot_description,
      vehicle_type_description
    ]

    desc = parts.join(' | ')
    desc += " (#{@t[:cancelled]})" if @reservation.cancelled?
    desc
  end

  def unit_price
    @reservation.cancelled? ? 0.0 : @reservation.price
  end

  def artikel_nr
    return nil if @reservation.cancelled?

    config = Rails.application.config.cashctrl[:artikel]
    key = artikel_key
    config[key]
  end

  def weekend?
    @reservation.date.saturday? || @reservation.date.sunday?
  end

  private

  def artikel_key
    vehicle = @reservation.vehicle.motorcycle? ? 'motorcycle' : 'car'
    duration = @reservation.half_day? ? 'halfday' : 'fullday'
    day_type = weekend? ? 'weekend' : 'weekday'
    "#{vehicle}_#{duration}_#{day_type}".to_sym
  end

  def time_slot_description
    if @reservation.half_day?
      @reservation.am? ? @t[:half_day_am] : @t[:half_day_pm]
    else
      @t[:full_day]
    end
  end

  def vehicle_type_description
    @reservation.vehicle.motorcycle? ? @t[:motorcycle] : @t[:car]
  end
end
