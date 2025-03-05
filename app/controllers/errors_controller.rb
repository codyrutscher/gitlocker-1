class ErrorsController < ApplicationController
  def not_found
    @error_details = request.env['action_dispatch.exception'].message
    render template: 'errors/not_found', status: :not_found
  end

  def unacceptable
    @error_details = request.env['action_dispatch.exception'].message
    render template: 'errors/unacceptable', status: :unprocessable_entity
  end

  def internal_server_error
    @error_details = request.env['action_dispatch.exception'].message
    render template: 'errors/internal_server_error', status: :internal_server_error
  end
end
