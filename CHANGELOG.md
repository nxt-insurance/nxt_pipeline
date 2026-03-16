## nxt_pipeline 2.1.0 (16.03.2026)

- Migrate CI from CircleCI/Travis to GitHub Actions (matrix: Ruby 3.3, 3.4, 4.0)
- Add `required_ruby_version >= 3.3` to gemspec
- Update bundler 2.1.4 → 4.0.8, replace pry-byebug with pry, drop guard-rspec
- Remove rspec_junit_formatter (CircleCI-only dependency)
- Replace `OpenStruct` with `Data.define` in error details (removed from Ruby 4.0 stdlib)
- Fix Ruby 4.0 strict kwargs separation in `Step#execute_callable`
- Make `Pipeline#step` argument optional (fixes kwargs-only calls under Ruby 4.0)
- Rename default branch master → main

## nxt_pipeline 2.0.0 (10.05.2022)

- Rename `Pipeline.execute` to `Pipeline.call`
- Pipeline#call accepts any argument instead of just key word arguments or hashes 
- Introduce constructor resolvers
- Expose :new and :call directly on NxtPipeline instead of only through NxtPipeline::Pipeline class
- Change step DSL: Introduce constructor option to specify the constructor to use for a step
- Introduce Configurations
- Expose step.status and step.meta_data accessors to set status and meta_data of steps in constructors
- Change arguments of error callbacks to be error, acc, step instead of acc, step, error and only pass by arity of callback

## nxt_pipeline 1.0.0 (24.11.2020)

Replace after and before execute hooks with proper callbacks.
Introduce before, after and around step callbacks

## nxt_pipeline 0.4.3 (October 20, 2020)

Add new attribute readers on step object.

After executing a step execution_finished_at execution_started_at and execution_duration
will be set and can be accessed via attribute readers.

## nxt_pipeline 0.4.2 (October 12, 2020)

* Fix bug when registering an error without passing arguments in which case the callback didn't get executed. More info: https://github.com/nxt-insurance/nxt_pipeline/issues/39

## nxt_pipeline 0.4.1 (March 13, 2020)

* Fix deprecation warnings for Ruby 2.7

## nxt_pipeline 0.2.0 (March 10, 2019)

* Added pipeline callback support.

  *Nils Sommer*

* Renamed class and method names

  Renamed `NxtPipeline::Segment` to `NxtPipeline::Step`.
  Renamed `NxtPipeline::Pipeline::segment` to `NxtPipeline::Pipeline::step`.
  Renamed `NxtPipeline::Pipeline#call` to `NxtPipeline::Pipeline#run`.
  Renamed `NxtPipeline::Pipeline#burst?` to `NxtPipeline::Pipeline#failed?`.
  Renamed `NxtPipeline::Pipeline#burst_segment` to `NxtPipeline::Pipeline#failed_step`.
  Renamed `NxtPipeline::Pipeline::rescue_segment_burst` to `NxtPipeline::Pipeline::rescue_errors`.

  *Nils Sommer*

* Setup [guard](https://github.com/guard/guard) to run specs upon file changes during development.

  *Nils Sommer*

* Added CHANGELOG file.

  *Nils Sommer*

## nxt_pipeline 0.1.0 (February 25, 2019)

* Initial Release.

  *Nils Sommer*
