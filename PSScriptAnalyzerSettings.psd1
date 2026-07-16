@{
    ExcludeRules = @(
        # All pipeline-accepting functions are single-object by design;
        # adding empty process {} blocks would be noise with no behavioral change.
        'PSUseProcessBlockForPipelineCommand'

        # Get-DM* cmdlets declare OutputType as the per-item pipeline type (the correct
        # PowerShell convention for "emits zero-or-more of X"), but return @(...)-wrapped
        # collections / ArrayLists. PSScriptAnalyzer's static inference reports the literal
        # collection type (System.Object[] / ArrayList) rather than the element type, so this
        # rule is a false positive for the getter idiom used throughout this module.
        'PSUseOutputTypeCorrectly'
    )
}
