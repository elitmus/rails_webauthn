class CreateWebauthnCredentials < ActiveRecord::Migration[7.0]
  def change
    create_table :rails_webauthn_webauthn_credentials do |t|
      t.integer :user_id, null: false   # ← change from t.bigint to t.integer
      t.string :external_id, null: false
      t.string :public_key, null: false
      t.integer :sign_count, null: false, default: 0
      t.string :nickname, null: false

      t.timestamps
    end

    add_index :rails_webauthn_webauthn_credentials, :user_id
    add_foreign_key :rails_webauthn_webauthn_credentials, :users, column: :user_id
  end
end