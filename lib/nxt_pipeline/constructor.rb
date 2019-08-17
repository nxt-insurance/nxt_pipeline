module NxtPipeline
  class Constructor
    def initialize(name, opts, block)
      @name = name
      @block = block
      @opts = opts
      @type_resolver = opts.fetch(:type_resolver) { ->(potential_type) { potential_type == name } }
    end

    attr_reader :opts, :block

    delegate :call, :arity, to: :block

    def resolve_type(potential_match)
      type_resolver.call(potential_match)
    end

    private

    attr_reader :type_resolver
  end
end
