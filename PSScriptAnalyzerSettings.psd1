@{
    ExcludeRules = @(
        # All pipeline-accepting functions are single-object by design;
        # adding empty process {} blocks would be noise with no behavioral change.
        'PSUseProcessBlockForPipelineCommand'
    )
}
