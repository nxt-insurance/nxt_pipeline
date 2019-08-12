module NxtPipeline
  class Step
    def initialize(type, constructor, index, **opts)
      define_attr_readers(opts)

      @type = type
      @index = index
      @opts = opts
      @constructor = constructor
      @to_s = "#{opts.merge(type: type)}"

      @status = nil
      @result = nil
      @error = nil
    end

    attr_reader :type, :result, :status, :error, :opts, :index
    attr_accessor :to_s

    def execute(**opts)
      guard_args = [opts, self]
      if_guard_args = guard_args.take(if_guard.arity)
      unless_guard_guard_args = guard_args.take(unless_guard.arity)

      if !unless_guard.call(*unless_guard_guard_args) && if_guard.call(*if_guard_args)
        self.result = constructor.call(self, **opts)
      end

      set_status
      result
    rescue StandardError => e
      self.status = :failed
      self.error = e
      raise
    end

    def type?(potential_type)
      type.to_sym == potential_type.to_sym
    end

    private

    attr_writer :result, :status, :error
    attr_reader :constructor

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
  end
end
