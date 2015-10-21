module Hilda::ModuleGraphAutosave
  extend ActiveSupport::Concern

  included do
    after_find :set_last_saved
    after_save :set_last_saved
    attr_accessor :last_saved
  end

  def module_finished(mod,execute_next=true)
    autosave # this has to be before super, otherwise the whole graph is executed before autosave
    super
  end

  def module_starting(mod)
    super
    autosave
  end

  def graph_stopped
    super
    autosave
  end

  def graph_finished
    super
    autosave
  end

  def autosave
    save if change_time > last_saved
  end

  private

    def set_last_saved
      self.last_saved = change_time
    end
  
end
