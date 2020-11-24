## nxt_pipeline 1.0.0 (24.11.2020)

Replace after and before execute with proper callbacks

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
