module Api
  module V1
    class DevicesController < ApplicationController
      skip_before_action :authenticate_device!, only: [ :create ]

      # POST /api/v1/devices
      # Registers a new device. Requires user credentials in the body.
      # Returns the raw token once — store it, it is never returned again.
      def create
        user = User.find_by(email: params[:email]&.downcase)
        unless user&.authenticate(params[:password])
          return render json: { error: "Invalid credentials" }, status: :unauthorized
        end

        if user.otp_required_for_login
          unless user.validate_otp!(params[:otp_attempt].to_s)
            return render json: { error: "Invalid OTP" }, status: :unauthorized
          end
        end

        raw_token    = SecureRandom.hex(32)
        token_digest = Digest::SHA256.hexdigest(raw_token)

        device = user.devices.build(
          name:         params[:name],
          platform:     params[:platform],
          token_digest: token_digest
        )

        if device.save
          render json: {
            id:       device.id,
            name:     device.name,
            platform: device.platform,
            token:    raw_token
          }, status: :created
        else
          render json: { errors: device.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/devices/:id
      # Updates last_seen_at and/or is_active.
      def update
        device = current_user.devices.find(params[:id])

        attrs = { last_seen_at: Time.current }
        attrs[:is_active] = params[:is_active] unless params[:is_active].nil?

        device.update!(attrs)
        render json: { id: device.id, name: device.name, is_active: device.is_active, last_seen_at: device.last_seen_at }
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Device not found" }, status: :not_found
      end
    end
  end
end
