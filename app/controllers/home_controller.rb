class HomeController < ApplicationController
  def privacy
  end

  def terms
  end

  def refund_policy
  end

  def pricing
  end
  
  def contact
  end

  def deployment_options
  end

  def explore
    current_user.update(state: User.states[:buyer])
    redirect_to marketplace_root_path
  end

  def robots
    respond_to :text
  end
end
