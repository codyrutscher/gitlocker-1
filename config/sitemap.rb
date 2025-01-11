# Set the host name for URL creation
SitemapGenerator::Sitemap.default_host = "https://www.coderz.us"

SitemapGenerator::Sitemap.adapter = SitemapGenerator::S3Adapter.new(
  fog_provider: "AWS",
  aws_access_key_id: ENV["AWS_ACCESS_KEY_ID"],
  aws_secret_access_key: ENV["AWS_SECRET_ACCESS_KEY"],
  fog_directory: ENV["S3_BUCKET"],
  fog_region: ENV["AWS_REGION"]
)

SitemapGenerator::Sitemap.sitemaps_host = "https://www.coderz.us"
SitemapGenerator::Sitemap.public_path = "tmp/"
SitemapGenerator::Sitemap.sitemaps_path = "sitemaps/"
SitemapGenerator::Sitemap.max_sitemap_links = ENV['MAX_SITEMAP_LINKS'].to_i if ENV['MAX_SITEMAP_LINKS'].present?

SitemapGenerator::Sitemap.create(compress: false) do
  add marketplace_root_path
  # Product
  Product.find_each do |product|
    add marketplace_library_path(product), lastmod: product.updated_at, priority: 0.5
  end

  # Blog
  Blog.find_each do  |blog|
    add blog_path(blog), lastmod: blog.updated_at, priority: 0.5
  end

  # Language
  Language.find_each do |language|
    add marketplace_language_path(language), priority: 0.5
  end

  # Category
  Category.find_each do |category|
    add marketplace_category_path(category), priority: 0.5
  end

  # Creator
  User.find_each do |creator|
    add marketplace_creator_path(creator.id), priority: 0.5
  end
end
