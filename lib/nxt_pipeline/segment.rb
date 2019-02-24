module NxtPipeline
  class Segment
    def initialize(*args)
      validate_initialize_args(*args).each do |key, value|
        send("#{key}=", value)
      end
    end

    def pipe_through
      # Public interface of Segment, to be implemented by subclasses.
      raise NotImplementedError
    end

    def self.[](*args)
      raise ArgumentError, 'Arguments missing' if args.empty?

      Class.new(self) do
        self.segment_args = args.map(&:to_sym)

        self.segment_args.each do |segment_arg|
          attr_accessor segment_arg
        end
      end
    end

    private

    cattr_accessor :segment_args, instance_writer: false, default: []

    def validate_initialize_args(*args)
      raise ArgumentError, arguments_missing_msg(self.segment_args) if args.empty?

      keyword_args = args.first
      missing_keyword_args = self.segment_args.reject do |arg|
        keyword_args.include?(arg)
      end

      raise ArgumentError, arguments_missing_msg(missing_keyword_args) if missing_keyword_args.any?

      keyword_args.slice(*self.segment_args)
    end

    def arguments_missing_msg(missing_arg_keys)
      "Arguments missing: #{missing_arg_keys.map { |a| "#{a}:" }.join(', ')}"
    end
  end
end
