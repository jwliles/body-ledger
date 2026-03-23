module Api
  module V1
    class AuthController < ApplicationController
      skip_before_action :authenticate_device!

      # POST /api/v1/auth/login
      # Validates email + password and returns basic user info.
      # Clients use this to confirm credentials before registering a device.
      def login
        user = User.find_by(email: params[:email]&.downcase)

        if user&.authenticate(params[:password])
          render json: { id: user.id, email: user.email, time_zone: user.time_zone }
        else
          render json: { error: "Invalid email or password" }, status: :unauthorized
        end
      end
    end
  end
end
