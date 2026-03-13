# frozen_string_literal: true

module Admin
  class InvoicesController < BaseController
    before_action :set_invoice, only: %i[show send_email download_pdf refresh_status]

    def index
      @invoices = Invoice.includes(:user)

      if params[:period].present?
        @invoices = @invoices.where(period_start: params[:period].to_date)
      end

      if params[:status].present?
        @invoices = @invoices.where(status: params[:status])
      end

      if params[:q].present?
        @invoices = @invoices.joins(:user).where('users.email ILIKE ?', "%#{params[:q]}%")
      end

      @invoices = @invoices.order(created_at: :desc)
                           .page(params[:page])
                           .per(25)
    end

    def show; end

    def send_email
      client = CashctrlClient.new
      client.send_invoice_email(@invoice.cashctrl_invoice_id)
      @invoice.update!(sent_at: Time.current, status: :sent)

      redirect_to admin_invoices_path, notice: 'Invoice sent successfully'
    end

    def download_pdf
      client = CashctrlClient.new
      pdf_data = client.get_invoice_pdf(@invoice.cashctrl_invoice_id)

      send_data pdf_data,
                filename: "invoice-#{@invoice.id}.pdf",
                type: 'application/pdf',
                disposition: 'attachment'
    end

    def refresh_status
      sync_invoice_status(@invoice)
      redirect_to admin_invoices_path, notice: 'Status refreshed'
    end

    def refresh_all
      Invoice.open.find_each { |invoice| sync_invoice_status(invoice) }
      redirect_to admin_invoices_path, notice: 'All statuses refreshed'
    end

    private

    def set_invoice
      @invoice = Invoice.find(params[:id])
    end

    def sync_invoice_status(invoice)
      return unless invoice.cashctrl_invoice_id

      client = CashctrlClient.new
      data = client.get_invoice(invoice.cashctrl_invoice_id)

      new_status = case data['statusId']
                   when 7 then :draft
                   when 16 then :sent
                   when 17 then :paid
                   else invoice.status
                   end

      invoice.update!(
        status: new_status,
        cashctrl_status: data['statusId'].to_s,
        paid_at: new_status == :paid ? Time.current : invoice.paid_at
      )
    end
  end
end
