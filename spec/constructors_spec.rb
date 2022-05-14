RSpec.describe 'NxtPipeline' do
  context 'global constructors' do
    class Stringer
      def initialize(string)
        @string = string
      end

      def call
        @string
      end
    end

    before do
      NxtPipeline.constructor(:test) do |acc|
        [acc, "global test constructor"].join(' ')
      end

      NxtPipeline.constructor(:global) do |acc|
        [acc, "global constructor"].join(' ')
      end
    end

    subject do
      NxtPipeline.new do |pipeline|
        pipeline.constructor(:test) do |acc|
          [acc, "local test constructor"].join(' ')
        end

        pipeline.constructor(:local) do |acc|
          [acc, "local constructor"].join(' ')
        end

        pipeline.step Stringer, constructor: :test
        pipeline.step Stringer, constructor: :global
        pipeline.step Stringer, constructor: :local
      end
    end

    it 'uses the correct constructors' do
      expect(subject.call('')).to eq(' local test constructor global constructor local constructor')
    end
  end
end