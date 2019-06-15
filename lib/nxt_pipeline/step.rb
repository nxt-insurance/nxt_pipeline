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

    attr_accessor :constructor # TODO: Why is this an accessor? --> Should be private reader
    attr_reader :type, :result, :status, :error, :opts

    def execute(arg)
      self.result = constructor.call(self, arg)
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

    def define_attr_readers(opts)
      opts.each do |key, value|
        define_singleton_method key.to_s do
          value
        end
      end
    end

    def set_status
      self.status = result.present? ? :success : :failed
    end
  end
end
