# frozen_string_literal: true

# User controller
class UsersController < AuthorizableController

  def edit
    @user = User.find(params[:id])
    authorize @user
  end

  def index
    @users = policy_scope(User.all.order(:last_name))
  end

  def show
    @user = User.find(params[:id])
    authorize @user
    @reservations = @user.reservations.active_in_the_future

    if @user.prepaid? && @user.cashctrl_private_account_id.present?
      begin
        @prepaid_balance = CashctrlClient.new.get_account_balance(@user.cashctrl_private_account_id)
      rescue StandardError => e
        Rails.logger.warn("Failed to fetch prepaid balance for user #{@user.id}: #{e.message}")
        @prepaid_balance = nil
      end
    end
  end

  def update
    @user = User.find(params[:id])
    authorize @user

    if @user.update(user_params)
      respond_to do |format|
        flash[:success] = 'User was successfully updated.'
        format.html { redirect_to user_path(@user.id) }
      end
    else
      respond_to do |format|
        flash[:danger] = 'There was a problem updating the user.'
        format.html { render :edit }
      end
    end
  end

  def create_topup_invoice
    @user = User.find(params[:id])
    authorize @user

    amount = params[:topup_amount].to_f
    if amount <= 0
      redirect_to user_path(@user), alert: 'Top-up amount must be greater than 0.'
      return
    end

    client = CashctrlClient.new
    person_id = client.find_or_create_person(@user)
    account_id = client.resolve_account_id(@user.cashctrl_private_account_id)

    cashctrl_invoice_id = client.create_invoice(
      person_id: person_id,
      date: Date.today,
      due_days: 30,
      items: [{ name: 'Aufladung Parkkonto / Parking account top-up', unit_price: amount, quantity: 1 }],
      account_id: account_id
    )

    redirect_to user_path(@user), notice: "Top-up invoice for CHF #{amount} created (CashCtrl ##{cashctrl_invoice_id})."
  rescue StandardError => e
    redirect_to user_path(@user), alert: "Failed to create top-up invoice: #{e.message}"
  end

  private

  def user_params
    if current_user.admin?
      params.require(:user).permit(
        :password,
        :password_confirmation,
        :role,
        :disabled,
        :billing_type,
        :cashctrl_private_account_id
      )
    else
      params.require(:user).permit([])
    end
  end
end
