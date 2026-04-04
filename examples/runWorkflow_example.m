%% DWiM Unified Workflow Example
% Demonstrates end-to-end DICOM pipeline using dwim.runWorkflow()
%
% Prerequisites:
%   - Orthanc server running (default: http://localhost:8042)
%   - DWiM added to MATLAB path: addpath('path/to/DWiM')

addpath(fullfile(fileparts(mfilename('fullpath')), '..'));

%% Basic usage (default config)
studyID = '2b08116a-f739e7be-20b50985-82000266-1167fd7b';
result = dwim.runWorkflow(studyID);

%% Custom config
config = dwim.defaultConfig();
config.exportPNG   = true;
config.buildVolume = true;
config.outputDir   = './my_output';

result = dwim.runWorkflow(studyID, config);

%% Inspect results
fprintf('Study path:  %s\n', result.study);
fprintf('Has metadata: %d\n', ~isempty(result.metadata));
fprintf('Has volume:   %d\n', ~isempty(result.volume));

if ~isempty(result.volume)
    fprintf('Volume size: [%s]\n', num2str(size(result.volume)));
end
