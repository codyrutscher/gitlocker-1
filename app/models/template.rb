class Template < ApplicationRecord
    validates :name, presence: true, uniqueness: true
    validates :description, presence: true
    validates :default_url, presence: true
    validates :cloned_count, numericality: { greater_than_or_equal_to: 0 }
    has_one_attached :folder, dependent: :destroy
    has_many :products

    DEFAULT_TEMPLATES = [
        {
            name: "Next.js Boilerplate",
            description: "A boilerplate for Next.js projects with best practices.",
            url: "https://github.com/vercel/next.js/tree/canary/examples/with-typescript",
            image_url: "https://camo.githubusercontent.com/f21f1fa29dfe5e1d0772b0efe2f43eca2f6dc14f2fede8d9cbef4a3a8dc5319e/68747470733a2f2f6173736574732e76657263656c2e636f6d2f696d6167652f75706c6f61642f76313636323133303535392f6e6578746a732f49636f6e5f6c696768745f6261636b67726f756e642e706e67"
        },
        {
            name: "React Vite Starter",
            description: "A starter template for React projects using Vite.",
            url: "https://github.com/vitejs/vite/tree/main/packages/create-vite/template-react",
            image_url: "https://vitejs.dev/logo-with-shadow.png"
        },
        {
            name: "Vue 3 Starter",
            description: "A starter template for Vue 3 projects.",
            url: "https://github.com/vuejs/vue-next-webpack-preview/tree/master",
            image_url: "https://vuejs.org/images/logo.png"
        },
        {
            name: "SvelteKit Starter",
            description: "A starter template for SvelteKit projects.",
            url: "https://github.com/sveltejs/kit",
            image_url: "https://kit.svelte.dev/svelte-kit-machine.png"
        },
        {
            name: "Nuxt.js Boilerplate",
            description: "A boilerplate for Nuxt.js projects.",
            url: "https://github.com/nuxt/create-nuxt-app",
            image_url: "https://nuxt.com/assets/design-kit/logo-green.svg"
        },
        {
            name: "Astro Blog Starter",
            description: "A blog starter template for Astro projects.",
            url: "https://github.com/withastro/astro/tree/main/examples/blog",
            image_url: "https://astro.build/assets/press/astro-logo-dark.png"
        },
        {
            name: "Remix Starter",
            description: "A starter template for Remix projects.",
            url: "https://github.com/remix-run/remix/tree/main/examples/basic",
            image_url: "https://remix.run/img/og.png"
        },
        {
            name: "Gatsby Starter",
            description: "A starter template for Gatsby projects.",
            url: "https://github.com/gatsbyjs/gatsby-starter-default/tree/master",
            image_url: "gatsby.svg"
        },
        {
            name: "SolidJS Starter",
            description: "A starter template for SolidJS projects.",
            url: "https://github.com/solidjs/templates",
            image_url: "solidjs.svg"
        },
        {
            name: "Tailwind CSS UI Kit",
            description: "A UI kit for Tailwind CSS projects.",
            url: "https://github.com/estevanmaito/tailwind-starter-kit/tree/master",
            image_url: "https://tailwindcss.com/_next/static/media/tailwindcss-mark.79614a5f61617ba49a0891494521226b.svg"
        },
        {
            name: "Node.js Express API",
            description: "A starter template for Node.js Express API projects.",
            url: "https://github.com/expressjs/express/tree/master",
            image_url: "https://expressjs.com/images/express-facebook-share.png"
        },
        {
            name: "Fastify Starter",
            description: "A starter template for Fastify projects.",
            url: "https://github.com/fastify/fastify",
            image_url: "https://fastify.io/img/fastify-logo-menu.d13f8da7a965c800.png"
        },
        {
            name: "Flask RESTful API",
            description: "A starter template for Flask RESTful API projects.",
            url: "https://github.com/flask-restful/flask-restful/tree/master",
            image_url: "https://flask.palletsprojects.com/en/2.3.x/_images/flask-logo.png"
        },
        {
            name: "Spring Boot Microservices",
            description: "A starter template for Spring Boot microservices projects.",
            url: "https://github.com/spring-projects/spring-boot",
            image_url: "spring.svg"
        },
        {
            name: "NestJS Starter",
            description: "A starter template for NestJS projects.",
            url: "https://github.com/nestjs/typescript-starter/tree/master",
            image_url: "nestjs.svg"
        },
        {
            name: "Koa.js API Starter",
            description: "A starter template for Koa.js API projects.",
            url: "https://github.com/koajs/koa/tree/master",
            image_url: "https://koajs.com/public/images/koa-logo.png"
        },
        {
            name: "Go Fiber API",
            description: "A starter template for Go Fiber API projects.",
            url: "https://github.com/gofiber/fiber",
            image_url: "gifibre.svg"
        },
        {
            name: "ASP.NET Core API",
            description: "A starter template for ASP.NET Core API projects.",
            url: "https://github.com/dotnet/aspnetcore",
            image_url: "https://dotnet.microsoft.com/static/images/redesign/social/square.png"
        },
        {
            name: "Ruby on Rails API",
            description: "A starter template for Ruby on Rails API projects.",
            url: "https://github.com/rails/rails",
            image_url: "rails.svg"
        },
        {
            name: "Next.js + Prisma + PostgreSQL",
            description: "A starter template for Next.js projects with Prisma and PostgreSQL.",
            url: "https://github.com/prisma/prisma-examples/tree/latest",
            image_url: "prisma.svg"
        },
        {
            name: "MERN Boilerplate",
            description: "A boilerplate for MERN stack projects.",
            url: "https://github.com/Hashnode/mern-starter/tree/master",
            image_url: "mongodb.png"
        },
        {
            name: "MEVN Starter",
            description: "A starter template for MEVN stack projects.",
            url: "https://github.com/madlabsinc/mevn-cli/tree/master",
            image_url: "vuejs.svg"
        },
        {
            name: "T3 Stack Starter",
            description: "A starter template for T3 stack projects.",
            url: "https://github.com/t3-oss/create-t3-app",
            image_url: "t3light.svg"
        },
        {
            name: "Bun + React + SQLite",
            description: "A starter template for Bun projects with React and SQLite.",
            url: "https://github.com/oven-sh/bun",
            image_url: "bun.svg"
        },
        {
            name: "RedwoodJS Starter",
            description: "A starter template for RedwoodJS projects.",
            url: "https://github.com/redwoodjs/redwood",
            image_url: "redwood.svg"
        },
        {
            name: "Blitz.js Boilerplate",
            description: "A boilerplate for Blitz.js projects.",
            url: "https://github.com/blitz-js/blitz",
            image_url: "https://blitzjs.com/img/blitz-logo.svg"
        },
        {
            name: "Strapi + Next.js Starter",
            description: "A starter template for Strapi projects with Next.js.",
            url: "https://github.com/strapi/strapi-starter-next-blog/tree/master",
            image_url: "strapi.svg"
        },
        {
            name: "Flask + React Boilerplate",
            description: "A boilerplate for Flask projects with React.",
            url: "https://github.com/fastapi/full-stack-fastapi-template/tree/master",
            image_url: "https://repository-images.githubusercontent.com/232478616/8b60df00-78de-11ea-9e00-8be386671022"
        },
        {
            name: "Django + Vue Boilerplate",
            description: "A boilerplate for Django projects with Vue.",
            url: "https://github.com/gtalarico/django-vue-template/tree/master",
            image_url: "https://static.djangoproject.com/img/logos/django-logo-positive.svg"
        },
        {
            name: "Hugging Face AI Chatbot",
            description: "A starter template for AI chatbot projects using Hugging Face.",
            url: "https://github.com/huggingface/transformers",
            image_url: "hugging.svg"
        },
        {
            name: "OpenAI GPT App Starter",
            description: "A starter template for OpenAI GPT projects.",
            url: "https://github.com/openai/gpt-3/tree/master",
            image_url: "https://openai.com/content/images/2022/05/openai-avatar.png"
        },
        {
            name: "TensorFlow.js ML Model",
            description: "A starter template for TensorFlow.js machine learning projects.",
            url: "https://github.com/tensorflow/tfjs/tree/master",
            image_url: "tensorflow.svg"
        },
        {
            name: "Stable Diffusion Image Generator",
            description: "A starter template for image generation projects using Stable Diffusion.",
            url: "https://github.com/CompVis/stable-diffusion",
            image_url: "https://raw.githubusercontent.com/CompVis/stable-diffusion/main/assets/stable-diffusion-v1-4-sampling.png"
        },
        {
            name: "Whisper Speech-to-Text API",
            description: "A starter template for speech-to-text projects using Whisper.",
            url: "https://github.com/openai/whisper",
            image_url: "https://openai.com/content/images/2022/09/Whisper-Header-ipad-1.jpg"
        },
        {
            name: "AI-based Voice Cloning App",
            description: "A starter template for AI-based voice cloning projects.",
            url: "https://github.com/CorentinJ/Real-Time-Voice-Cloning/tree/master",
            image_url: "https://raw.githubusercontent.com/CorentinJ/Real-Time-Voice-Cloning/master/demo_output.gif"
        },
        {
            name: "Pinecone + Next.js AI Search",
            description: "A starter template for AI search projects using Pinecone and Next.js.",
            url: "https://github.com/pinecone-io/examples/tree/master",
            image_url: "pinecone.svg"
        },
        {
            name: "Dockerized Next.js App",
            description: "A starter template for Dockerized Next.js projects.",
            url: "https://github.com/vercel/next.js/tree/canary/examples/with-docker",
            image_url: "docker.svg"
        },
        {
            name: "Kubernetes Node.js API",
            description: "A starter template for Kubernetes projects with Node.js API.",
            url: "https://github.com/kubernetes/examples/tree/master",
            image_url: "https://kubernetes.io/images/favicon.png"
        },
        {
            name: "Terraform AWS Deployment",
            description: "A starter template for AWS deployment projects using Terraform.",
            url: "https://github.com/hashicorp/terraform",
            image_url: "terraform.svg"
        },
        {
            name: "Serverless Functions Starter",
            description: "A starter template for serverless functions projects.",
            url: "https://github.com/serverless/serverless",
            image_url: "serverless.svg"
        },
        {
            name: "GitHub Actions CI/CD",
            description: "A starter template for CI/CD projects using GitHub Actions.",
            url: "https://github.com/actions/starter-workflows",
            image_url: "github_actions.svg"
        },
        {
            name: "Kubernetes Full-Stack App",
            description: "A starter template for full-stack applications on Kubernetes.",
            url: "https://github.com/kubernetes/examples/tree/master",
            image_url: "https://kubernetes.io/images/kubernetes-horizontal-color.png"
        },
        {
            name: "Nginx Reverse Proxy Starter",
            description: "A starter template for Nginx reverse proxy projects.",
            url: "https://github.com/nginxinc/docker-nginx/tree/master",
            image_url: "nginx.svg"
        },
        {
            name: "GraphQL API with Apollo",
            description: "A starter template for GraphQL API projects using Apollo.",
            url: "https://github.com/apollographql/apollo-server",
            image_url: "apollo.svg"
        },
        {
            name: "PostgreSQL + Prisma ORM",
            description: "A starter template for PostgreSQL projects with Prisma ORM.",
            url: "https://github.com/prisma/prisma-examples/tree/latest",
            image_url: "prisma_orm.svg"
        },
        {
            name: "Redis + Node.js Caching",
            description: "A starter template for caching projects using Redis and Node.js.",
            url: "https://github.com/luin/ioredis",
            image_url: "redis.svg"
        }
    ]
end
