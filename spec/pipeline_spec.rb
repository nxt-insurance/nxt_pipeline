RSpec.describe NxtPipeline::Pipeline do
  let(:pipe_attr) { %w[Ruby is awesome] }

  let(:uppercase_segment) do
    Class.new(NxtPipeline::Segment) do
      def pipe_through
        words.map(&:upcase)
      end
    end
  end

  let(:sort_segment) do
    Class.new(NxtPipeline::Segment) do
      def pipe_through
        words.sort
      end
    end
  end

  subject do
    klass = Class.new(NxtPipeline::Pipeline) do
      pipe_attr :words
    end

    klass.mount_segment uppercase_segment
    klass.mount_segment sort_segment

    klass
  end

  it 'pipes the pipe attr through the segments and returns them transformed' do
    expect(subject.new(words: pipe_attr).call).to eq %w[AWESOME IS RUBY]
  end
end
