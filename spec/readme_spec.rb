RSpec.describe NxtPipeline::Pipeline do
  class Validator
    def self.call(*args)
      new(*args).call
    end

    attr_accessor :error

    def error
      @error = nil
    end
  end

  class TypeChecker < Validator
    def initialize(value, type)
      @value = value
      @type = type
    end

    attr_reader :value, :type

    def call
      return if value.is_a?(type)
      self.error = "Value does not match type #{type}"
    end
  end

  class Size < Validator
    def initialize(value, size)
      @value = value
      @size = size
    end

    attr_reader :value, :size

    def call
      return if value.size > 0
      self.error = "Value size must be greater #{size}"
    end
  end

  class Pattern < Validator
    def initialize(value, pattern)
      @value = value
      @pattern = pattern
    end

    attr_reader :value, :pattern

    def call
      return if value.size > 0
      self.error = "Value size cannot be zero"
    end
  end

  context 'with constructor' do
    subject do
      NxtPipeline::Pipeline.new do |p|
        p.constructor(:service, default: true) do |strings, step|
          step.argument.new(strings).call
        end

        p.step Compacter
        p.step Stripper
        p.step Upcaser
      end
    end

    let(:input) { ['', nil, 'andy  ', '   hanna'] }

    it do
      expect(subject.call(input)).to eq(['ANDY', 'HANNA'])
    end
  end

  context 'with proc as constructor' do
    subject do
      NxtPipeline::Pipeline.new do |p|
        p.constructor(:service, default: true) do |step, strings:|
          result = step.argument.new(strings).call
          result && { strings: result }
        end

        p.step Compacter, constructor: -> (s, strings:) { { strings: s.argument.call(strings: strings * 2) } }
        p.step Stripper
        p.step Upcaser
      end
    end

    let(:input) { ['', nil, 'andy  ', '   hanna'] }

    it do
      expect(subject.call(strings: input)).to eq(strings: ["ANDY", "HANNA", "ANDY", "HANNA"])
    end
  end
end