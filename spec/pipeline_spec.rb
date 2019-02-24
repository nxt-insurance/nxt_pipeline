RSpec.describe NxtPipeline::Pipeline do
  context 'with reliable segments' do
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

  context 'with failing segments' do
    class TestError < StandardError; end

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

    let(:failing_segment) do
      class FailingSegment < NxtPipeline::Segment
        def pipe_through
          raise TestError, 'This segment has burst!'
        end
      end

      FailingSegment
    end

    context 'without rescuing for segment bursts' do
      subject do
        klass = Class.new(NxtPipeline::Pipeline) do
          pipe_attr :words
        end

        klass.mount_segment uppercase_segment
        klass.mount_segment failing_segment
        klass.mount_segment sort_segment

        klass
      end

      it 'raises an error and remembers which segment burst' do
        expect { subject.new(words: pipe_attr).call }.to raise_error(
          TestError,
          'This segment has burst!'
        )
      end

      it 'remembers the segment that burst' do
        pipeline = subject.new(words: pipe_attr)
        pipeline.call rescue TestError

        expect(pipeline.burst_segment).to eq 'failing_segment'
        expect(pipeline.burst?).to be_truthy
      end
    end

    context 'when rescuing for segment bursts' do
      subject do
        klass = Class.new(NxtPipeline::Pipeline) do
          pipe_attr :words
        end

        klass.mount_segment uppercase_segment
        klass.mount_segment failing_segment
        klass.mount_segment sort_segment

        klass.rescue_segment_burst TestError do |error, burst_segment|
          puts "Failed in segment #{burst_segment} with #{error.class}: #{error.message}"
        end

        klass
      end

      it 'should call the block defined for segment burst rescues' do
        expect { subject.new(words: pipe_attr).call }.to raise_error(
          TestError,
          'This segment has burst!'
        ).and output("Failed in segment failing_segment with TestError: This segment has burst!\n").to_stdout
      end
    end
  end
end
