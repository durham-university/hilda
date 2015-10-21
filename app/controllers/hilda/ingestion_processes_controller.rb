module Hilda
  class IngestionProcessesController < Hilda::ApplicationController
    before_action :set_ingestion_process, only: [:show, :edit, :update, :destroy, :start_module, :reset_module]
    before_action :set_ingestion_module, only: [:update, :start_module, :reset_module]

    def use_layout?
      !(params.key?(:no_layout) || params[:hilda_ingestion_process].try(:key?,:no_layout))
    end

    def index
      @ingestion_processes = IngestionProcess.all
    end

    def show
    end

    def new
      @ingestion_process = IngestionProcess.new
    end

    def edit
      render layout: false unless use_layout?
    end

    def create_test_process
      graph = IngestionProcess.new
      graph.add_start_module(Hilda::Modules::FileReceiver) \
           .add_module(Hilda::Modules::FileMetadata, metadata_fields: {
              title: {label: 'Title', type: :string},
              test: {label: 'Test', type: :string}
             }) \
           .add_module(Hilda::Modules::DebugModule, sleep: 20 ) \
           .add_module(Hilda::Modules::Preservation) \
           .add_module(Hilda::Modules::DebugModule,
              param_defs: { test: {label: 'test param', type: :string, default: 'moo'} },
              info_template: 'hilda/modules/debug_info',
              sleep: 20 )
      graph
    end

    def create
      @ingestion_process = create_test_process

      respond_to do |format|
        if @ingestion_process.save
          format.html { redirect_to @ingestion_process, notice: 'Ingestion process was successfully created.' }
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
        redirect_to @ingestion_process
      end
    end

    def destroy
      @ingestion_process.destroy
      respond_to do |format|
        format.html { redirect_to ingestion_processes_url, notice: 'Ingestion process was successfully destroyed.' }
        format.json { head :no_content }
      end
    end

    def start_module
      raise 'Module is not ready to run' unless @ingestion_module.ready_to_run?
      @ingestion_module.run_status=:queued
      @ingestion_module.changed!
      Hilda::Jobs::IngestionJob.new(resource: @ingestion_process, module_name: @ingestion_module).queue_job
      # queue_job saves the object

      disable_layout = use_layout? ? {} : { layout: false }
      render :edit, {notice: 'Module was successfully queued to be ran.'}.merge(disable_layout)
    end

    def reset_module
      @ingestion_module.reset_module
      @ingestion_process.save!
      disable_layout = params.key?(:no_layout) ? { layout: false } : {}
      render :edit, {notice: 'Module was reset.'}.merge(disable_layout)
    end

    private

      def receive_module_params
        if @ingestion_module.receive_params(params[:hilda_ingestion_process])
          if @ingestion_process.save
            disable_layout = use_layout? ? {} : { layout: false }
            render :edit, {notice: 'Ingestion process was successfully updated.'}.merge(disable_layout)
#            redirect_to @ingestion_process, notice: 'Ingestion process was successfully updated.'
          else
            raise 'Error saving ingestion process'
          end
        else
          raise 'Module refused submitted values'
        end
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

      # Never trust parameters from the scary internet, only allow the white list through.
      def ingestion_process_params
        params[:ingestion_process]
      end
  end
end
