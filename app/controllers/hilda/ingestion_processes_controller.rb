module Hilda
  class IngestionProcessesController < Hilda::ApplicationController
    before_action :set_ingestion_process, only: [:show, :edit, :update, :destroy]

    # GET /ingestion_processes
    # GET /ingestion_processes.json
    def index
      @ingestion_processes = IngestionProcess.all
    end

    # GET /ingestion_processes/1
    # GET /ingestion_processes/1.json
    def show
    end

    # GET /ingestion_processes/new
    def new
      @ingestion_process = IngestionProcess.new
    end

    # GET /ingestion_processes/1/edit
    def edit
    end

    # POST /ingestion_processes
    # POST /ingestion_processes.json
    def create
      @ingestion_process = IngestionProcess.new(ingestion_process_params)

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

    # PATCH/PUT /ingestion_processes/1
    # PATCH/PUT /ingestion_processes/1.json
    def update
      respond_to do |format|
        if @ingestion_process.update(ingestion_process_params)
          format.html { redirect_to @ingestion_process, notice: 'Ingestion process was successfully updated.' }
          format.json { render :show, status: :ok, location: @ingestion_process }
        else
          format.html { render :edit }
          format.json { render json: @ingestion_process.errors, status: :unprocessable_entity }
        end
      end
    end

    # DELETE /ingestion_processes/1
    # DELETE /ingestion_processes/1.json
    def destroy
      @ingestion_process.destroy
      respond_to do |format|
        format.html { redirect_to ingestion_processes_url, notice: 'Ingestion process was successfully destroyed.' }
        format.json { head :no_content }
      end
    end

    private
      # Use callbacks to share common setup or constraints between actions.
      def set_ingestion_process
        @ingestion_process = IngestionProcess.find(params[:id])
      end

      # Never trust parameters from the scary internet, only allow the white list through.
      def ingestion_process_params
        params[:ingestion_process]
      end
  end
end
