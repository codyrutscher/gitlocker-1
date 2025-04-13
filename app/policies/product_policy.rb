class ProductPolicy < ApplicationPolicy
  class Scope < Scope
    # NOTE: Be explicit about which records you allow access to!
    # def resolve
    #   scope.all
    # end
  end

  def edit?
    return false if user.blank?

    record.user_id == user.id
  end

  def purchasable?
    return false unless record.active?

    return false unless record.published?

    return false if user&.purchased_products&.include?(record)

    user.blank? || record.user_id != user.id
  end

  def download_able?
    return false unless record.active?

    return false unless record.published?

    return false unless record.purchases.where(user_id: user&.id).any?

    user.blank? || record.user_id != user.id
  end

  def reviewable?
    return false unless record.active?

    return false unless record.published?

    return false if user.blank?

    return false if record.reviews.pluck(:user_id).include?(user.id)

    record.user_id != user.id
  end

  def viewable?
    return false unless record.active?

    return false unless record.published?

    return false if user.blank?

    return true if record.purchases.pluck(:user_id).include?(user.id)

    record.user_id != user.id
  end

  def editable?
    
    return false unless record.active?

    return false unless record.published?

    return false if user.blank?

    return true if record.purchases.pluck(:user_id).include?(user.id)

    record.user_id == user.id
  end

  def can_access_vcs_functionality?
    return false unless record.active?

    return false unless record.published?

    return false if user.blank?

    user_ids = record.purchases.pluck(:user_id) + record.reviews.pluck(:user_id) + [record.user_id]
    user_ids.include?(user.id)
  end
end
