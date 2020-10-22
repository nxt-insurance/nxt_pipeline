module NxtPipeline
  class Callbacks < NxtRegistry::Registry
    def initialize
      super(accessor: :callbacks)

      register(:execution) do
        register(:before, [])
        register(:after, [])
        register(:around, [])
      end

      register(:step, accessor) do
        register(:before, [])
        register(:after, [])
        register(:around, [])
      end
    end
  end
end
