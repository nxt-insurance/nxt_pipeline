## nxt_pipeline 0.4.1 (TBD)

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