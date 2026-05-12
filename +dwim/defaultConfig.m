function config = defaultConfig()
%DEFAULTCONFIG Default configuration for DWiM unified workflow
%
%   config = dwim.defaultConfig()
%
%   Returns a configuration struct with default settings for runWorkflow.
%   Override any field before passing to dwim.runWorkflow().
%
%   Example:
%       config = dwim.defaultConfig();
%       config.exportPNG = true;
%       result = dwim.runWorkflow('studyID', config);

    config.doAnonymize    = true;
    config.exportMetadata = true;
    config.exportPNG      = false;
    config.buildVolume    = true;
    config.outputDir      = './dwim_output';
end
