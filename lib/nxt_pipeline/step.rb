module NxtPipeline
  class Step
    def initialize(type, constructor, index, **opts)
      define_attr_readers(opts)

      @type = type
      @index = index
      @opts = opts
      @constructor = constructor
      @to_s = "#{opts.merge(type: type)}"
      @options_mapper = opts[:map_options]

      @status = nil
      @result = nil
      @error = nil
      @mapped_options = nil
    end

    attr_reader :type, :result, :status, :error, :opts, :index, :mapped_options
    attr_accessor :to_s

    alias_method :name=, :to_s=
    alias_method :name, :to_s

    def execute(**opts)
      mapper = options_mapper || default_options_mapper
      self.mapped_options = mapper.call(opts)

      guard_args = [opts, self]

      if_guard_args = guard_args.take(if_guard.arity)
      unless_guard_guard_args = guard_args.take(unless_guard.arity)

      if !unless_guard.call(*unless_guard_guard_args) && if_guard.call(*if_guard_args)
        constructor_args = [self, opts]
        constructor_args = constructor_args.take(constructor.arity)
        self.result = constructor.call(*constructor_args) # here we could pass in the mapped options
      end

      set_status
      result
    rescue StandardError => e
      self.status = :failed
      self.error = e
      raise
    end

    def type?(potential_type)
      constructor.resolve_type(potential_type)
    end

    private

    attr_writer :result, :status, :error, :mapped_options
    attr_reader :constructor, :options_mapper

    def if_guard
      opts.fetch(:if) { guard(true) }
    end

    def unless_guard
      opts.fetch(:unless) { guard(false) }
    end

    def guard(result)
      -> { result }
    end

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

    def default_options_mapper
      # returns an empty hash
      ->(changeset) { {} }
    end
  end
end
