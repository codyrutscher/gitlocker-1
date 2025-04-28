class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable, :omniauthable, omniauth_providers: [:github, :gitlab, :bitbucket]

  enum :registration_status, {
    registration_pending: 0,
    registration_completed: 1
  }

  enum state: { buyer: 0, seller: 1 }

  extend FriendlyId
  friendly_id :email_stripped, use: :slugged, slug_column: :username

  has_many :products, dependent: :destroy
  has_many :reviews, dependent: :destroy
  has_many :cart_items, dependent: :destroy
  has_many :products_in_cart, through: :cart_items, source: :product
  has_many :purchases, dependent: :destroy
  has_many :purchased_products, through: :purchases, source: :product
  has_many :payments, dependent: :destroy
  has_many :refunds, dependent: :destroy
  has_many :user_categories, dependent: :destroy
  has_many :categories, through: :user_categories
  has_many :active_categories, -> {
    where("user_categories.active = ?", true)
  }, through: :user_categories, source: :category
  has_many :user_languages, dependent: :destroy
  has_many :languages, through: :user_languages
  has_many :active_languages, -> {
    where("user_languages.active = ?", true)
  }, through: :user_languages, source: :language
  has_many :sales, through: :products, source: :purchases
  has_one :account, dependent: :destroy
  has_many :notifications, as: :recipient

  has_many :followed_users, foreign_key: :follower_id, class_name: 'Follow'
  has_many :followees, through: :followed_users
  has_many :following_users, foreign_key: :followee_id, class_name: 'Follow'
  has_many :followers, through: :following_users
  has_many :product_users
  has_many :products, through: :product_users

  scope :total_earnings, -> { order(total_earning: :desc) }
  scope :newest, -> { order(created_at: :desc) }
  scope :oldest, -> { order(created_at: :asc) }
  scope :name_asc, -> { order(name: :asc) }
  scope :github_username_asc, -> { order(username: :asc) }
  scope :most_followers, -> {
    left_joins(:followers)
    .group('users.id')
    .order('COUNT(follows.follower_id) DESC NULLS LAST')
  }

  scope :sort_by_criteria, ->(criteria) {
    case criteria
    when 'total_earnings' then total_earnings
    when 'newest' then newest
    when 'oldest' then oldest
    when 'most_followers' then most_followers
    when 'name_asc' then name_asc
    when 'github_username_asc' then github_username_asc
    else newest # Default sorting
    end
  }

  has_one_attached :profile_picture
  has_many_attached :projects

  validates :username, presence: true, uniqueness: { case_sensitive: false }

  scope :sellers, -> { where(seller: true) }

  include PgSearch::Model
  pg_search_scope :search,
                  against: [:name, :email, :username],
                  using: {
                    tsearch: { prefix: true }
                  }

  # Unified filtering and sorting method
  def self.filter_and_sort(params)
    users = self.all

    # Apply search filter
    users = users.search(params[:search]) if params[:search].present?

    # Apply sorting
    if params[:creator_sort_by].present?
      users = users.sort_by_criteria(params[:creator_sort_by])
    else 
      users = users.sort_by_criteria('newest')
    end

    users
  end

  def self.from_omniauth(access_token)
    provider = access_token.provider
    token    = access_token.credentials.token
    email    = access_token.info.email
    name     = access_token.info.name
    username = access_token.info.nickname || access_token.info.username
    user     = User.find_by(email: email)
    if user && provider == 'github'
      user.update(token: token, name: name, username: username)
    elsif user && provider == 'gitlab'
      user.update(gitlab_token: token, name: name, username: username)
    elsif user && provider == 'bitbucket'
      user.update(bitbucket_token: token, name: name, username: username)
    else
      user = User.create(
        email: email,
        password: Devise.friendly_token[0, 20],
        token: provider == 'github' ? token : nil,
        gitlab_token: provider == 'gitlab' ? token : nil,
        bitbucket_token: provider == 'bitbucket' ? token : nil,
        name: name,
        username: username
      )
    end
    user
  end
  
  def clone_repositories(git_url)
    "git clone https://oauth2:#{token}@github.com/#{username}/{repository_name}"
  end

  def email_stripped
    email.split("@").first
  end

  def total_sales_amount_in_dollars
    total_sale_value = sales.where(pending: true, refund: false).sum(:price_cents)
    total_sale_value *= 0.9 
    total_sale_value /= 100.0
  end

  def send_on_create_confirmation_instructions
    return
  end
end

