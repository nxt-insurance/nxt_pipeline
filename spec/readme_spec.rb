RSpec.describe NxtPipeline::Pipeline do
  class Validator
    def self.call(value, **options)
      new(value, **options).call
    end

    attr_accessor :error
  end

  class TypeChecker < Validator
    def initialize(value, type:)
      @value = value
      @type = type
    end

    attr_reader :value, :type

    def call
      return if value.is_a?(type)
      self.error = "Value does not match type #{type}"
    end
  end

  class MinSize < Validator
    def initialize(value, size:)
      @value = value
      @size = size
    end

    attr_reader :value, :size

    def call
      return if value.size >= size
      self.error = "Value size must be greater #{size-1}"
    end
  end

  class MaxSize < Validator
    def initialize(value, size:)
      @value = value
      @size = size
    end

    attr_reader :value, :size

    def call
      return if value.size <= size
      self.error = "Value size must be less #{size+1}"
    end
  end

  class Pattern < Validator
    def initialize(value, pattern:)
      @value = value
      @pattern = pattern
    end

    attr_reader :value, :pattern

    def call
      return if value.match?(pattern)
      self.error = "Value does not fulfill pattern: #{pattern}"
    end
  end

  class Uniqueness < Validator
    def initialize(value, scope:)
      @value = value
      @scope = scope
    end

    attr_reader :value, :scope

    def call
      return self if scope.count { |item| item == value }
      self.error = "Value is not unique in: #{scope}"
      self
    end
  end

  context 'with constructor' do
    subject do
      NxtPipeline::Pipeline.new do |p|
        p.constructor(:validator, default: true) do |acc, step|
          validator = step.argument.new(acc.fetch(:value), **step.options)
          validator.call
          acc[:errors] << validator.error if validator.error.present?

          acc
        end

        p.step TypeChecker, options: { type: String }
        p.step MinSize, options: { size: 4 }
        p.step MaxSize, options: { size: 10 }
        p.step Uniqueness, options: { scope: ['andy', 'aki', 'lütfi', 'rapha'] }
      end
    end

    let(:input) { { value: 'aki', errors: [] } }

    it do
      expect(subject.call(input)).to eq(value: 'aki', errors: ['Value size must be greater 3'])
    end
  end
end