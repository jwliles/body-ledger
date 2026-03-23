class ApplicationController < ActionController::API
  before_action :authenticate_device!

  private

  def authenticate_device!
    token = extract_bearer_token
    return render_unauthorized unless token

    # SHA-256 digest allows O(1) indexed lookup. Raw token is 32 random bytes
    # (256-bit entropy), so the digest is cryptographically adequate.
    digest = Digest::SHA256.hexdigest(token)
    @current_device = Device.find_by(token_digest: digest, is_active: true)
    return render_unauthorized unless @current_device

    @current_device.update_column(:last_seen_at, Time.current)
    @current_user = @current_device.user
  end

  def current_device = @current_device
  def current_user   = @current_user

  def extract_bearer_token
    header = request.headers["Authorization"]
    return nil unless header&.start_with?("Bearer ")
    header.delete_prefix("Bearer ")
  end

  def render_unauthorized
    render json: { error: "Unauthorized" }, status: :unauthorized
  end
end
