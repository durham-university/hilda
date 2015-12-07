module Hilda::Jobs::HildaJob
  extend ActiveSupport::Concern

  def queue
    Hilda.queue
  end
end
