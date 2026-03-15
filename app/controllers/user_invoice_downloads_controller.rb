# frozen_string_literal: true

class UserInvoiceDownloadsController < AuthorizableController
  def show
    @user = User.find(params[:user_id])
    authorize @user, :show?
    invoice = @user.invoices.find(params[:id])

    client = CashctrlClient.new
    pdf_data = client.get_invoice_pdf(invoice.cashctrl_invoice_id)

    send_data pdf_data,
              filename: "invoice-#{invoice.period_start.strftime('%Y-%m')}.pdf",
              type: 'application/pdf',
              disposition: 'attachment'
  rescue StandardError => e
    Rails.logger.error("PDF download failed: #{e.message}")
    redirect_to user_billing_path(@user), alert: 'Failed to download PDF.'
  end
end
