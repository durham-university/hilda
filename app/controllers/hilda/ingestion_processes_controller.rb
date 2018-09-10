module Hilda
  class IngestionProcessesController < Hilda::ApplicationController
    
    before_action :authenticate_user!
    before_action :set_ingestion_process, only: [:show, :edit, :update, :destroy, :start_graph, :reset_graph, :rollback_graph, :start_module, :reset_module, :enable_module, :disable_module, :query_module, :rollback_module]
    before_action :authorize_resource!
    before_action :set_ingestion_module, only: [:update, :start_module, :reset_module, :query_module, :rollback_module, :enable_module, :disable_module]
    before_action :set_ingestion_process_template, only: [:create]
    after_action :autosave_graph, only: [:edit]

    def initialize(*args)
      @module_notices = {}
      super(*args)
    end

    def use_layout?
      !(params.key?(:no_layout) || params[:ingestion_process].try(:key?,:no_layout))
    end

    def self.index_processes
      IngestionProcess.all.from_solr!.order('system_create_dtsi desc')
    end

    def index
      @ingestion_processes = self.class.index_processes
    end

    def show
    end

    def new
      @ingestion_process = IngestionProcess.new
      @templates = Hilda::IngestionProcessTemplate.all.to_a.sort do |a,b|
        [a.order_hint,a.to_s] <=> [b.order_hint,b.to_s]
      end
    end

    def edit
      render layout: false unless use_layout?
    end

    def create
      @ingestion_process = @ingestion_process_template.build_process
      @ingestion_process.owner = current_user.try(:user_key)

      respond_to do |format|
        if @ingestion_process.save
          format.html { redirect_to edit_ingestion_process_path(@ingestion_process), notice: 'Ingestion process was successfully created.' }
          format.json { render :show, status: :created, location: @ingestion_process }
        else
          format.html { render :new }
          format.json { render json: @ingestion_process.errors, status: :unprocessable_entity }
        end
      end
    end

    def update
      if @ingestion_module
        receive_module_params
      else
        # set graph attributes, if there ever are any
        redirect_to edit_ingestion_process_path(@ingestion_process)
      end
    end

    def destroy
      @ingestion_process.destroy
      respond_to do |format|
        format.html { redirect_to ingestion_processes_url, notice: 'Ingestion process was successfully destroyed.' }
        format.json { head :no_content }
      end
    end
    
    def rollback_graph
      @ingestion_process.rollback_graph
      if @ingestion_process.save!
        flash[:notice] = "Graph was successfully rolled back"
      else
        flash[:alert] = "Error rolling back graph"
      end
      disable_layout = use_layout? ? {} : { layout: false }
      respond_to do |format|
        format.html { redirect_to edit_ingestion_process_path(@ingestion_process) }
        format.json { head :no_content }
      end
    end
    
    def reset_graph
      begin
        @ingestion_process.reset_graph
        if @ingestion_process.save!
          flash[:notice] = "Graph was successfully reset"
        else
          flash[:alert] = "Error saving ingestion process"
        end
      rescue StandardError => e
        flash[:alert] = "Error resetting module: #{e.to_s}"
      end
      disable_layout = params.key?(:no_layout) ? { layout: false } : {}
      render :edit, disable_layout
    end
    
    def start_graph
      if [:initialized, :submitted, :paused, :error].include?(@ingestion_process.run_status)
        modules = @ingestion_process.ready_modules
        if modules.any?
          modules.each do |mod| 
            add_module_notice("Module was queued to be run", :success, mod)
            mod.run_status=:queued
            mod.changed!
          end
          begin
            Hilda::Jobs::IngestionJob.new(resource: @ingestion_process, user: current_user).queue_job
          rescue StandardError => e
            flash[:alert] = e.to_s
          end
          # queue_job saves the object          
        else
          flash[:alert] = "No modules are ready to run"
        end
      else
        flash[:alert] = "Cannot start graph in current state of #{@ingestion_process.run_status}"
      end
      disable_layout = use_layout? ? {} : { layout: false }
      render :edit, {}.merge(disable_layout)
    end
    
    def disable_module
      @ingestion_module.disable!
      if @ingestion_process.save!
        add_module_notice("Module disabled", :success)
      else
        add_module_notice("Unable to disable module", :success)        
      end
      disable_layout = use_layout? ? {} : { layout: false }
      render :edit, {}.merge(disable_layout)
    end
    
    def enable_module
      @ingestion_module.enable!
      if @ingestion_process.save!
        add_module_notice("Module enabled", :success)
      else
        add_module_notice("Unable to enable module", :success)        
      end
      disable_layout = use_layout? ? {} : { layout: false }
      render :edit, {}.merge(disable_layout)
    end

    def start_module
      if @ingestion_module.ready_to_run?
        @ingestion_module.run_status=:queued
        @ingestion_module.changed!
        Hilda::Jobs::IngestionJob.new(resource: @ingestion_process, module_name: @ingestion_module, user: current_user).queue_job
        # queue_job saves the object
        add_module_notice("Module was queued to be run", :success)
      else
        add_module_notice("Module is not ready to run")
      end

      disable_layout = use_layout? ? {} : { layout: false }
      render :edit, {}.merge(disable_layout)
    end

    def reset_module
      begin
        reset_modules = @ingestion_process.reset_module_cascading(@ingestion_module)
        if reset_modules.any?
          if @ingestion_process.save!
            reset_modules.each do |mod|
              add_module_notice('Module was successfully reset', :success, mod)
            end
          else
            add_module_notice('Error saving ingestion process')
          end
        end
      rescue StandardError => e
        add_module_notice("Error resetting module: #{e.to_s}")
      end
      disable_layout = params.key?(:no_layout) ? { layout: false } : {}
      render :edit, disable_layout
    end
    
    def rollback_module
      begin
        rolledback_modules = @ingestion_process.rollback_module_cascading(@ingestion_module)
        if rolledback_modules.any?
          if @ingestion_process.save!
            rolledback_modules.each do |mod|
              add_module_notice('Module was successfully rolled back', :success, mod)
            end
          else
            add_module_notice('Error saving ingestion process')
          end
        end
      rescue StandardError => e
        add_module_notice("Error rolling back module: #{e.to_s}")
      end
      disable_layout = params.key?(:no_layout) ? { layout: false } : {}
      render :edit, disable_layout
    end

    def query_module
      begin
        response = @ingestion_module.query_module(params[:ingestion_process]) || { status: "ERROR", error_message: "Error querying module"}
        response[:status] = 'OK' unless response.key?(:status)
        render json: response
      rescue StandardError => e
        render json: { status: "ERROR", error_message: "Error querying module: #{e.to_s}"}
      end
    end

    def purge_old_processes
      ps = Hilda::IngestionProcess.all.from_solr!.order('system_create_dtsi asc').to_a
      psf = ps[0..-20].select do |p| p.run_status == :finished && (DateTime.now - p.modified_date).to_f > 14 end
      psf.each do |p| Hilda::IngestionProcess.find(p.id).destroy end            

      redirect_to ingestion_processes_url, notice: "#{psf.count} old ingestion processes purged."
    end

    private
    
      def autosave_graph
        @ingestion_process.autosave
      end

      def authorize_resource!
        authorize!(params[:action].to_sym, @ingestion_process || Hilda::IngestionProcess)
      end

      # levels: :info, :success, :warning, :danger
      def add_module_notice(message, level=:danger, mod=nil)
        mod ||= @ingestion_module
        @module_notices[mod] ||= []
        @module_notices[mod] << {message: message, level: level}
      end

      def receive_module_params
        begin
          raise "Module cannot receive params" unless @ingestion_module.can_receive_params?

          if @ingestion_module.receive_params(params[:ingestion_process])
            if @ingestion_process.save
              add_module_notice('Module parameters were successfully updated', :success)
            else
              add_module_notice('Error saving ingestion process')
            end
          end
        rescue StandardError => e
          add_module_notice("Error setting module parameters: #{e.to_s}")
        end
        disable_layout = use_layout? ? {} : { layout: false }
        render :edit, disable_layout
      end

      # Use callbacks to share common setup or constraints between actions.
      def set_ingestion_process
        @ingestion_process = IngestionProcess.find(params[:id])
      end

      def set_ingestion_module
        if params[:module]
          @ingestion_module = @ingestion_process.find_module(params[:module])
          raise 'Module not found' unless @ingestion_module
        end
      end

      def set_ingestion_process_template
        template_id_or_key = params[:ingestion_process].try(:[],:template)
        raise 'Template not found' unless template_id_or_key
        result = Hilda::IngestionProcessTemplate.where( id: template_id_or_key )
        if result.any?
          @ingestion_process_template = result.first
        else
          result = Hilda::IngestionProcessTemplate.where( template_key: template_id_or_key )
          if result.any?
            @ingestion_process_template = result.first
          else
            raise 'Template not found'
          end
        end
      end

      # Never trust parameters from the scary internet, only allow the white list through.
      def ingestion_process_params
        params[:ingestion_process]
      end
  end
end
