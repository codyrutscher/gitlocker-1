class Product < ApplicationRecord
  extend FriendlyId
  friendly_id :name, use: :slugged

  monetize :price_cents

  belongs_to :user
  has_many :notifications, dependent: :destroy
  has_many :reviews, dependent: :destroy
  has_many :purchases, dependent: :destroy
  has_one_attached :folder, dependent: :destroy
  has_one_attached :video_file, dependent: :destroy
  has_one :refund, dependent: :destroy

  has_many :product_categories, dependent: :destroy
  has_many :categories, through: :product_categories
  has_many :active_categories, -> {
    where("product_categories.active = ?", true)
  }, through: :product_categories, source: :category

  has_many :product_languages, dependent: :destroy
  has_many :languages, through: :product_languages
  has_many :active_languages, -> { where("product_languages.active = ?", true) }, through: :product_languages, source: :language

  has_many_attached :covers, dependent: :destroy
  has_many :likes, dependent: :destroy
  has_many :cart_items, dependent: :destroy
  has_one :featured_payment_intent, dependent: :destroy

  validates :name, presence: true, uniqueness: true, on: :create
  # validates :url, presence: true, uniqueness: { scope: :name }

  validate :validate_product_limit, on: :create

  accepts_nested_attributes_for :product_categories

  # Generate thumbnails only when covers are created or updated
  # after_commit :thumb_images, if: :saved_change_to_covers?

  default_scope { where(upload_complete: true) }

  scope :exclude_purchased, ->(user) { 
    where.not(id: user&.purchases&.pluck(:product_id))
  }

  scope :by_category, ->(category_name) {
    joins(:categories).where(categories: { name: category_name }) if category_name.present?
  }

  scope :by_language, ->(language_name) {
    joins(:languages).where(languages: { name: language_name }) if language_name.present?
  }

  scope :sort_by_criteria, ->(criteria) {
    case criteria
    when 'alphabetical_asc' then order(name: :asc)
    when 'alphabetical_desc' then order(name: :desc)
    when 'cheapest' then order(price_cents: :asc)
    when 'most_expensive' then order(price_cents: :desc)
   when 'most_likes'
    left_joins(:likes)
      .group('products.id')
      .order('COUNT(likes.id) DESC NULLS LAST')
    when 'most_recent' then order(created_at: :desc)
    when 'oldest' then order(created_at: :asc)
    else order(created_at: :desc) # Default sorting
    end
  }

  # Process the cover images and generate thumbnails
  def thumb_images
    covers.each do |cover|
      cover.variant(resize_to_limit: [264, 264]).processed if image_content_type?(cover)
    end
  end

  def image_content_type?(cover)
    cover.content_type.in?(%w[image/png image/jpg image/jpeg image/gif])
  end

  # Check if the covers were added or updated
  def saved_change_to_covers?
    covers.attached? && covers.any?(&:saved_changes?)
  end

  def thumb_image_url
    cover =  self.covers.first
    if image_content_type?(cover)
      url = cover.variant(resize_to_limit: [264,264]).url 
      return url unless url.blank?
    end
    cover.url
  end

  def self.filter_and_sort(params)
    products = self.includes(:categories, :languages, :likes)

    if params[:category].present?
      products = products.by_category(params[:category])
    end

    if params[:language].present?
      products = products.by_language(params[:language])
    end

    products = products.sort_by_criteria(params[:sort_by])
    products
  end

  include PgSearch::Model
  pg_search_scope :search,
                  against: [:name],
                  using: {
                    tsearch: { prefix: true }
                  }

  multisearchable against: [:name, :category_names, :description],associated_against: {
                  languages: [:name]
                  },
                  if: :published?

  DEFAULT_PRODUCT_IMAGES = [
    "featured/10-mini-JS-projects-for-beginners.png",
    "featured/a-bootstrap-html-template.png",
    "featured/backend-with-django.png",
    "featured/bug-finder.png",
    "featured/flask-react-app.png",
    "popular/open-source-DocuSign-alternative.png",
    "popular/pytides.png",
    "popular/redux-toolkit.png",
    "popular/sudoku-solver.png",
    "popular/typescript-complete-course.png"
  ]

  scope :recent, -> { order(created_at: :desc) }
  scope :published, -> { where(published: true) }

  def language_name
    languages.pluck(:name).join(", ")
  end

  def category_names
    active_categories.pluck(:name).join(" ")
  end

  # after_commit :seed_categories, on: :create
  def seed_categories
    product_categories_to_seed = Category.all.map do |category|
      ProductCategory.new(product: self, category: category)
    end
    ProductCategory.import(product_categories_to_seed)
  end

  def normalize_friendly_id(text)
    super.gsub(/\d+/, '')
  end

  def self.ransackable_attributes(auth_object = nil)
    ["active", "average_rating", "created_at", "description", "download_path", "featured", "id", "id_value", "name", "preview_video_url", "price_cents", "price_currency", "published", "purchases_count", "repo_id", "reviews_count", "slug", "updated_at", "url", "user_id"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["active_categories", "active_languages", "cart_items", "categories", "covers_attachments", "covers_blobs", "folder_attachment", "folder_blob", "languages", "likes", "pg_search_document", "product_categories", "product_languages", "purchases", "refund", "reviews", "user", "video_file_attachment", "video_file_blob"]
  end

  def self.ordered_by_purchase_count
    left_joins(:purchases)
      .group('products.id')
      .order('COUNT(purchases.id) DESC')
      .select('products.*, COUNT(purchases.id) AS purchase_count')
  end

  def purchase_count
    purchases.count
  end
  # def related_products
  #   related_by_categories = Product.with_attached_covers.where.not(id: self.id)
  #                                  .includes(:categories)
  #                                  .where(categories: { id: self.category_ids })
  #   related_by_languages = Product.with_attached_covers.where.not(id: self.id)
  #                                 .includes(:languages)
  #                                 .where(languages: { id: self.language_ids })
  #   (related_by_categories + related_by_languages).uniq.take(15)
  # end

  def related_products
    Product.with_attached_covers
       .joins(:categories, :languages)
       .where.not(id: self.id)
       .where('categories.id IN (?) OR languages.id IN (?)', self.category_ids, self.language_ids)
       .distinct
       .limit(5)
  end

  def more_from_this_creators
    user = self.user 
    products = user.products.order(created_at: :desc).limit(5)
  end

  def validate_product_limit
    return true unless user.is_new # Skip validation for users who are not new
  
    service = BillingService.new(user)
    user_limit = service.get_product_limit
  
    if user.products.count >= user_limit
      errors.add(:base, "Limit exceeded. Please upgrade the plan to add more products.",  code: 402)
    end
  end
end
