class TemplatesController < ApplicationController
    include ProductConcern
    before_action :set_template, only: [:show, :clone]
  
    # GET /templates
    def index
      @templates = Template.all
    end
  
    # GET /templates/:id
    def show
        @directory_tree_json = fetch_product_directory_tree(@template)
    end

    # GET templates/create_default_templates
    def create_default_templates
        Template.all.each do |template|
            if !Template::DEFAULT_TEMPLATES.any? { |default_template| default_template[:name] == template.name }
                template.destroy
            end
        end

        Template::DEFAULT_TEMPLATES.each do |template|
            if Template.exists?(name: template[:name])
                existing_template = Template.find_by(name: template[:name])
                existing_template.update(
                    description: template[:description],
                    default_url: template[:url]
                )
                load_repo_and_link_tree('', '', '', '', existing_template, template[:url]) if params[:update_tree_structure].present?
            else
                new_template = Template.create(
                    name: template[:name],
                    description: template[:description],
                    default_url: template[:url],
                    cloned_count: 0
                )
                load_repo_and_link_tree('', '', '', '', new_template, template[:url]) if new_template.persisted?
            end
        end
        redirect_to templates_path, notice: 'Default templates were created successfully.'
    end
  
    # PATCH/PUT /templates/:id
    def update
      if @template.update(template_params)
        redirect_to @template, notice: 'Template was successfully updated.'
      else
        render :edit
      end
    end
  
    # DELETE /templates/:id
    def destroy
      @template.destroy
      redirect_to templates_url, notice: 'Template was successfully deleted.'
    end
  
    # POST /templates/:id/clone
    def clone
      cloned_template = @template.dup
      cloned_template.name = "#{@template.name} (Clone)"
      if cloned_template.save
        @template.increment_clone_count
        redirect_to cloned_template, notice: 'Template cloned successfully.'
      else
        redirect_to @template, alert: 'Error cloning template.'
      end
    end
  
    private
  
    def set_template
      @template = Template.find(params[:id])
    end
  
    def template_params
      params.require(:template).permit(:name, :description, :default_url)
    end
  end
  