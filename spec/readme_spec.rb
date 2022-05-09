RSpec.describe NxtPipeline::Pipeline do

  class Service
    def self.call(strings:)
      new(strings).call
    end
  end

  class Upcaser < Service
    def initialize(strings)
      @strings = strings
    end

    def call
      @strings.map(&:upcase)
    end
  end

  class Stripper < Service
    def initialize(strings)
      @strings = strings
    end

    def call
      @strings.map(&:strip)
    end
  end

  class Compacter < Service
    def initialize(strings)
      @strings = strings
    end

    def call
      @strings.reject(&:blank?)
    end
  end

  context 'with constructor' do
    subject do
      NxtPipeline::Pipeline.new do |p|
        p.constructor(:service, default: true) do |step, strings:|
          result = step.argument.new(strings).call
          result && { strings: result }
        end

        p.step Compacter
        p.step Stripper
        p.step Upcaser
      end
    end

    let(:input) { ['', nil, 'andy', 'hanna'] }

    it do
      expect(subject.call(strings: input)).to eq(strings: ['ANDY', 'HANNA'])
    end
  end
end