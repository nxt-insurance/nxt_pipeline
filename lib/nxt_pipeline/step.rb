module NxtPipeline
  class Step
    def initialize(type, constructor, **opts)
      define_attr_readers(opts)

      @type = type
      @result = nil
      @opts = opts
      @status = nil
      @constructor = constructor
      @error = nil
    end

    attr_reader :type, :result, :status, :error, :opts

    def execute(arg)
      self.result = constructor.call(self, arg)
      set_status
      result
    rescue StandardError => e
      self.status = :failed
      self.error = e
      raise
    end

    def to_s
      "#{opts.merge(type: type)}"
    end

    private

    attr_writer :result, :status, :error
    attr_reader :constructor

    def define_attr_readers(opts)
      opts.each do |key, value|
        define_singleton_method key.to_s do
          value
        end
      end
    end

    def set_status
      self.status = result.present? ? :success : :skipped
    end
  end
end
