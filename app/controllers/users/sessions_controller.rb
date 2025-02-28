module Users
  class SessionsController < Devise::SessionsController
    include DeviseCallbacks

    def new
      self.resource = resource_class.new
      @github_email = cookies[:github_email]
      @gitlab_email = cookies[:gitlab_email]
      super
    end

    def create
      self.resource = warden.authenticate!(auth_options)
      sign_in(resource_name, resource)
      respond_with resource, location: after_sign_in_path_for(resource)
    rescue Warden::AuthenticationError
      flash[:alert] = "Invalid email or password."
      self.resource = resource_class.new
      render :new, status: :unprocessable_entity
    end

    def failure
      flash[:alert] = "Invalid email or password."
      redirect_to new_user_session_path, status: :unprocessable_entity
    end
  end
end
