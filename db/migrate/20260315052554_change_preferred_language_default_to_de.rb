class ChangePreferredLanguageDefaultToDe < ActiveRecord::Migration[7.1]
  def change
    change_column_default :users, :preferred_language, from: 'en', to: 'de'
    User.where(preferred_language: 'en').update_all(preferred_language: 'de')
  end
end
