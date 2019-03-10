[![CircleCI](https://circleci.com/gh/nxt-insurance/nxt_pipeline.svg?style=svg)](https://circleci.com/gh/nxt-insurance/nxt_pipeline)

# NxtPipeline

nxt_pipeline provides a DSL to structure the processing of an object (oil) through multiple steps by defining pipelines (which process the object) and segments (reusable steps used by the pipeline).

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'nxt_pipeline'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install nxt_pipeline

## Usage

Look how easy it is.

```ruby
class UppercaseSegment < NxtPipeline::Segment
  def pipe_through
    words.map(&:uppercase)
  end
end

class SortSegment < NxtPipeline::Segment
  def pipe_through
    words.sort
  end
end

class MyPipeline < NxtPipeline::Pipeline
  pipe_attr :words
  
  segment UppercaseSegment
  segment SortSegment
end

MyPipeline.new(words: %w[Ruby is awesome]).call
# => ["AWESOME", "IS", "RUBY"]
```

Basically you create a pipeline class that inherits from `NxtPipeline::Pipeline` and name the attribute you want to pass through the pipeline's segments with the `pipe_attr` class method.

You can add segments to the pipeline by using the `segment` class method in the pipeline class body. The segment classes inherit from `NxtPipeline::Segment` and have to implement a method `#pipe_through`. Inside of it, you can access the pipeline attr by its reader method (see example above).

You can also define behavior to execute when one of the pipelines raises an error by using `rescue_segment_burst`. The code given to it through a block is executed and given the original error as well as a string naming the segment where the error occured. Afterwards the error is reraised.

```ruby
class MyPipeline < NxtPipeline::Pipeline
  pipe_attr :words
  
  segment UppercaseSegment
  segment SortSegment
  
  rescue_segment_burst StandardError do |error, segment_failed_upon|
    puts "Failed in segment #{segment_failed_upon} with #{error.class}: #{error.message}"
  end
end

pipeline = MyPipeline.new(words: %w[Ruby is awesome])
pipeline.call
# => 'Failed in segment uppercase_segment with StandardError: Lorem ipsum'

pipeline.burst?
# => true
pipeline.burst_segment
# => 'uppercase_segment'
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bin/rspec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

You can also run `bin/guard` to automatically run specs when files are saved.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/nxt-insurance/nxt_pipeline.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
