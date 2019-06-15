module NxtPipeline
  class Logger
    def initialize
      @log = {}
    end

    attr_accessor :log

    def call(step)
      log[step.to_s] = step.status
    end
  end
end