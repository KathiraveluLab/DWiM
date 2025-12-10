%% Test Suite for dwim.extractMetadata (Week 4: Functional Validation)
clear; clc;

% Define path to the file 
sampleFile = 'image01.dcm'; 

%% Test 1: Functional Metadata Extraction
fprintf('Running Test 1: Real Metadata Extraction...\n');

if isfile(sampleFile)
    % 1. Run the function
    data = dwim.extractMetadata(sampleFile);
    
    % 2. Verify Output
    assert(isstruct(data), 'Output must be a struct.');
    assert(isfield(data, 'Filename'), 'Metadata missing Filename.');
    
    fprintf('Test 1 Passed: Successfully read metadata.\n');
else
    error('Test 1 Failed: image01.dcm is missing from the main folder.');
end

%% Test 2: Error Handling
fprintf('\nRunning Test 2: Missing File Handling...\n');
try
    dwim.extractMetadata('ghost_file.dcm');
    error('Test Failed: Should have errored on missing file.');
catch ME
    if strcmp(ME.identifier, 'dwim:extractMetadata:FileNotFound')
        fprintf('Test 2 Passed: Correctly caught missing file error.\n');
    else
        rethrow(ME); 
    end
end

fprintf('\nWeek 4 Testing Suite Completed Successfully.\n');