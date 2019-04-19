module NxtPipeline
  class Step
    def initialize(constructor, **opts)
      define_attr_readers(opts)
      @opts = opts
      @constructor = constructor
    end

    attr_accessor :constructor

    def execute(arg)
      constructor.call(self, arg)
      # instance_exec(arg, &constructor)
    end

    def to_s
      "#{self.class} opts => #{opts}"
    end

    private

    attr_reader :opts

    def define_attr_readers(opts)
      opts.each do |key, value|
        define_singleton_method key.to_s do
          value
        end
      end
    end
  end
end
