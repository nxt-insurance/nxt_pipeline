RSpec.describe 'NxtPipeline' do
  context 'global constructors' do
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

        pipeline.step OutputInput, constructor: :test
        pipeline.step OutputInput, constructor: :global
        pipeline.step OutputInput, constructor: :local
      end
    end

    it 'uses the correct constructors' do
      expect(subject.call('')).to eq(' local test constructor global constructor local constructor')
    end
  end
end