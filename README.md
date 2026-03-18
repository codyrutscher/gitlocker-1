# GitLocker

A marketplace platform for buying and selling code repositories, built with Ruby on Rails. Developers can list their GitHub, GitLab, and Bitbucket repositories as products, and buyers can browse, purchase, and download source code.

## Features

- **Repository Marketplace** — Browse, search, filter, and purchase code repositories
- **Multi-Provider Auth** — Sign in with GitHub, GitLab, or Bitbucket via OAuth
- **Stripe Payments** — Secure checkout, seller payouts, and refund processing
- **Seller Dashboard** — Track sales, earnings, and manage product listings
- **Product Management** — Upload covers, set pricing, categorize by language/category, feature products
- **In-Browser Code Editor** — View and edit repository files through the workflows interface
- **Reviews & Ratings** — Buyers can rate and review purchased products
- **Social Features** — Follow creators, like products, notifications
- **Full-Text Search** — Powered by `pg_search` with PostgreSQL
- **Blog & CMS** — Admin-managed blog with CKEditor rich text
- **Admin Panel** — ActiveAdmin dashboard for managing users, products, payments, and refunds
- **Templates** — Clone starter templates to bootstrap new projects
- **Background Jobs** — Sidekiq + GoodJob for async processing (syncing repos, notifications, cart cleanup)

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Rails 7.1 |
| Ruby | 3.2.3 |
| Database | PostgreSQL |
| Frontend | Hotwire (Turbo + Stimulus), Tailwind CSS |
| Auth | Devise + OmniAuth (GitHub, GitLab, Bitbucket) |
| Payments | Stripe |
| Search | pg_search |
| Background Jobs | Sidekiq, GoodJob |
| File Storage | Active Storage + AWS S3 |
| Admin | ActiveAdmin |
| View Components | ViewComponent |
| Deployment | Docker, Puma |

## Prerequisites

- Ruby 3.2.3
- PostgreSQL
- Redis (for Sidekiq)
- Node.js (for asset compilation)
- Stripe account (for payments)
- GitHub/GitLab/Bitbucket OAuth app credentials

## Setup

1. Clone the repository:

```bash
git clone https://github.com/codyrutscher/gitlocker-1.git
cd gitlocker-1
```

2. Install dependencies:

```bash
bundle install
```

3. Set up environment variables:

```bash
cp .env.sample .env
```

Fill in the required values in `.env`:

```
GITHUB_CLIENT_ID=
GITHUB_CLIENT_SECRET=
GITLAB_CLIENT_ID=
GITLAB_CLIENT_SECRET=
STRIPE_SECRET_KEY=
STRIPE_PUBLISHABLE_KEY=
```

4. Create and migrate the database:

```bash
bin/rails db:create db:migrate db:seed
```

5. Start the development server:

```bash
bin/dev
```

This runs both the Rails server and Tailwind CSS watcher via `Procfile.dev`.

## Running Tests

```bash
bundle exec rspec
```

## Docker

Build and run with Docker:

```bash
docker build -t gitlocker .
docker run -p 3000:3000 gitlocker
```

## Project Structure

```
app/
├── admin/          # ActiveAdmin resource definitions
├── components/     # ViewComponent classes and templates
├── controllers/    # Rails controllers (marketplace namespace for storefront)
├── jobs/           # Background jobs (Sidekiq/GoodJob)
├── mailers/        # Email delivery (SendGrid)
├── models/         # ActiveRecord models
├── notifications/  # Noticed notification classes
├── policies/       # Pundit authorization policies
├── services/       # Service objects (billing, payouts, downloads)
├── views/          # ERB templates with Tailwind CSS
└── javascript/     # Stimulus controllers
```

## License

All rights reserved.
