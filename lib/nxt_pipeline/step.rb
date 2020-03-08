module NxtPipeline
  class Step
    def initialize(argument, constructor, index, **opts)
      define_attr_readers(opts)

      @argument = argument
      @index = index
      @opts = opts
      @constructor = constructor
      @to_s = "#{opts.merge(argument: argument)}"
      @options_mapper = opts[:map_options]

      @status = nil
      @result = nil
      @error = nil
      @mapped_options = nil
    end

    attr_reader :argument, :result, :status, :error, :opts, :index, :mapped_options
    attr_accessor :to_s

    alias_method :name=, :to_s=
    alias_method :name, :to_s

    def execute(**changeset)
      mapper = options_mapper || default_options_mapper
      mapper_args = [changeset, self].take(mapper.arity)
      self.mapped_options = mapper.call(*mapper_args)

      guard_args = [changeset, self]

      if_guard_args = guard_args.take(if_guard.arity)
      unless_guard_guard_args = guard_args.take(unless_guard.arity)

      if !instrumentalize_callable(unless_guard, unless_guard_guard_args) && instrumentalize_callable(if_guard, if_guard_args)
        constructor_args = [self, changeset]
        constructor_args = constructor_args.take(constructor.arity)

        self.result = instrumentalize_callable(constructor, constructor_args)
      end

      set_status
      result
    rescue StandardError => e
      self.status = :failed
      self.error = e
      raise
    end

    # def type?(potential_type)
    #   constructor.resolve_type(potential_type)
    # end

    private

    attr_writer :result, :status, :error, :mapped_options
    attr_reader :constructor, :options_mapper
    
    def instrumentalize_callable(callable, args)
      if args.last.is_a?(Hash)
        callable.call(*args.take(args.length - 1), **args.last)
      else
        callable.call(*args)
      end
    end

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
