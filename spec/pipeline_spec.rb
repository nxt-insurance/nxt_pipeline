RSpec.describe NxtPipeline::Pipeline do
  let(:pipe_attr) { %w[Ruby is awesome] }
  
  context 'with reliable segments' do
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
  
  context 'callbacks' do
    let(:empty_segment) do
      Class.new(NxtPipeline::Segment) do
        def pipe_through
          words
        end
      end
    end
        
    subject do
      klass = Class.new(NxtPipeline::Pipeline) do
        pipe_attr :words
        
        def history
          @history ||= []
        end
      end

      klass.mount_segment empty_segment
      
      klass.before_each_segment do |pipeline|
        pipeline.history << 'Pipeline ran before_each_segment callback'
      end
      
      klass.after_each_segment do |pipeline|
        pipeline.history << 'Pipeline ran after_each_segment callback'
      end
      
      klass.around_each_segment do |pipeline, block|
        pipeline.history << 'Pipeline ran around_each_segment callback start'
        block.call
        pipeline.history << 'Pipeline ran around_each_segment callback end'
      end

      klass
    end
    
    it 'should execute the callbacks in the correct order' do
      pipeline = subject.new(words: pipe_attr)
      pipeline.call
      
      expect(pipeline.history).to eq [
        'Pipeline ran before_each_segment callback',
        'Pipeline ran around_each_segment callback start',
        'Pipeline ran around_each_segment callback end',
        'Pipeline ran after_each_segment callback',
      ]
    end
  end
end
