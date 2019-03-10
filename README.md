[![CircleCI](https://circleci.com/gh/nxt-insurance/nxt_pipeline.svg?style=svg)](https://circleci.com/gh/nxt-insurance/nxt_pipeline)

# NxtPipeline

nxt_pipeline provides a DSL to define pipeline classes which take an object and pass it through multiple steps which can read or modify the object.

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

Define a pipeline by defining class inheriting from `NxtPipeline::Pipeline` as shown above. The following examples shows a pipeline which takes an array of strings and passes it through multiple steps.

```ruby
class MyPipeline < NxtPipeline::Pipeline
  pipe_attr :words
  
  step UppercaseSegment
  step SortSegment
end
```

The steps are classes themselves which inherit from `NxtPipeline::Step` and have to implement a `#pipe_through` method.

```ruby
class UppercaseSegment < NxtPipeline::Step
  def pipe_through
    words.map(&:uppercase)
  end
end

class SortSegment < NxtPipeline::Step
  def pipe_through
    words.sort
  end
end
```

You can access the pipeline attribute defined by `pipe_attr` in the pipeline class by a reader method which is automatically defined by nxt_pipeline. Don't forget to return the pipeline attribute so that subsequent steps in the pipeline can take it up!

Here's how our little example pipeline behaves like in action:

```
MyPipeline.new(words: %w[Ruby is awesome]).run
# => ["AWESOME", "IS", "RUBY"]
```

### Callbacks

You can define callbacks that are automatically invoked for each step in the pipeline.

```ruby
class MyPipeline < NxtPipeline::Pipeline
  before_each_step do
    # Code run before each step.
  end
  
  after_each_step do
    # Code run after each step
  end
  
  around_each_step do |pipeline, segment|
    # Code run before each step
	segment.call
	# Code run after each step
  end
end
```

### Error handling

When everything works smoothly the pipeline calls one step after another, passing through the pipeline attribute and returning it as it gets it from the last step. However, you might want to define behavior the pipeline should perform in case one of the steps raises an error.

```ruby
class MyPipeline < NxtPipeline::Pipeline
  rescue_errors StandardError do |error, failed_step|
    puts "Step #{failed_step} failed with #{error.class}: #{error.message}"
  end
end
```

Keep in mind though that `rescue_errors` will reraise the error it caught. When you rescue this error in your application, the pipeline remembers if and how it failed.

```ruby
pipeline = MyPipeline.new(...)

begin
  pipeline.run
rescue => e
  pipeline.failed?
  #=> true
  
  pipeline.failed_step
  #=> :underscored_class_name_of_failed_step
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bin/rspec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

You can also run `bin/guard` to automatically run specs when files are saved.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/nxt-insurance/nxt_pipeline.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
