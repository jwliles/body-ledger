module Api
  module V1
    class AuthController < ApplicationController
      skip_before_action :authenticate_device!, only: [ :login, :register ]

      # POST /api/v1/auth/register
      def register
        user = User.new(
          email:     params[:email]&.downcase,
          time_zone: params[:time_zone]
        )
        user.password = params[:password]

        if user.save
          render json: { id: user.id, email: user.email, time_zone: user.time_zone }, status: :created
        else
          render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/auth/login
      # Validates email + password (and TOTP if enabled) and returns basic user info.
      def login
        user = User.find_by(email: params[:email]&.downcase)

        unless user&.authenticate(params[:password])
          return render json: { error: "Invalid email or password" }, status: :unauthorized
        end

        if user.otp_required_for_login
          unless user.validate_otp!(params[:otp_attempt].to_s)
            return render json: { error: "Invalid OTP" }, status: :unauthorized
          end
        end

        render json: { id: user.id, email: user.email, time_zone: user.time_zone }
      end

      # POST /api/v1/auth/totp_setup
      def totp_setup
        current_user.generate_otp_secret!
        uri = current_user.otp_provisioning_uri
        qr  = RQRCode::QRCode.new(uri).as_svg(module_size: 4)
        render json: { otp_provisioning_uri: uri, qr_code_svg: qr }
      end

      # POST /api/v1/auth/totp_verify
      def totp_verify
        if current_user.validate_otp!(params[:otp_attempt].to_s)
          current_user.update!(otp_required_for_login: true)
          render json: { message: "TOTP verified. Two-factor authentication is now required." }
        else
          render json: { error: "Invalid OTP code" }, status: :unprocessable_entity
        end
      end
    end
  end
end
