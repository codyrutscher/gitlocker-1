# Set the host name for URL creation
SitemapGenerator::Sitemap.default_host = "https://www.gitlocker.com"

SitemapGenerator::Sitemap.adapter = SitemapGenerator::S3Adapter.new(
  fog_provider: "AWS",
  aws_access_key_id: ENV["AWS_ACCESS_KEY_ID"],
  aws_secret_access_key: ENV["AWS_SECRET_ACCESS_KEY"],
  fog_directory: ENV["S3_BUCKET"],
  fog_region: ENV["AWS_REGION"]
)

SitemapGenerator::Sitemap.public_path = "tmp/"

SitemapGenerator::Sitemap.sitemaps_host = "https://#{ENV['S3_BUCKET']}.s3.us-east-2.amazonaws.com/"

SitemapGenerator::Sitemap.sitemaps_path = "sitemaps/"

SitemapGenerator::Sitemap.create(compress: false) do
  add marketplace_root_path
  # Product
  Product.find_each do |product|
    add product_path(product), lastmod: product.updated_at, priority: 0.5
  end

  # Blog
  Blog.find_each do  |blog|
    add blog_path(blog), lastmod: blog.updated_at, priority: 0.5
  end
end
