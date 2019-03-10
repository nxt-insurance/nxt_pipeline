module NxtPipeline
  class Step
    def initialize(*args)
      validate_initialize_args(*args).each do |key, value|
        send("#{key}=", value)
      end
    end

    def pipe_through
      # Public interface of Step, to be implemented by subclasses.
      raise NotImplementedError
    end

    def self.[](*args)
      raise ArgumentError, 'Arguments missing' if args.empty?

      Class.new(self) do
        self.step_args = args.map(&:to_sym)

        self.step_args.each do |step_arg|
          attr_accessor step_arg
        end
      end
    end

    private

    cattr_accessor :step_args, instance_writer: false, default: []

    def validate_initialize_args(*args)
      raise ArgumentError, arguments_missing_msg(self.step_args) if args.empty?

      keyword_args = args.first
      missing_keyword_args = self.step_args.reject do |arg|
        keyword_args.include?(arg)
      end

      raise ArgumentError, arguments_missing_msg(missing_keyword_args) if missing_keyword_args.any?

      keyword_args.slice(*self.step_args)
    end

    def arguments_missing_msg(missing_arg_keys)
      "Arguments missing: #{missing_arg_keys.map { |a| "#{a}:" }.join(', ')}"
    end
  end
end
