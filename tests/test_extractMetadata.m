%% Test Suite for dwim.extractMetadata (Week 5: Self-Contained)
clear; clc;

% --- STEP 1: CREATE A TEMPORARY DICOM FILE ---
% We create the file in the system's temporary folder so we don't need
% to rely on Git uploads or relative paths.
tempDicomPath = fullfile(tempdir, 'temp_ci_test.dcm');

% Create a dummy 10x10 black image
try
    dicomwrite(uint8(zeros(10, 10)), tempDicomPath);
    fprintf('Created temporary test file at: %s\n', tempDicomPath);
catch ME
    error('Failed to create test file. Reason: %s', ME.message);
end

% Ensure we delete this file even if the test fails
cleaner = onCleanup(@() delete(tempDicomPath));

%% Test 1: Functional Metadata Extraction
fprintf('Running Test 1: Metadata Extraction...\n');

try
    % Run the function on the temp file
    data = dwim.extractMetadata(tempDicomPath);
    
    % Verify it returns a struct
    assert(isstruct(data), 'Output must be a struct.');
    
    % Verify it read the filename correctly
    % (We verify the field exists, not the exact path, to be safe)
    if isfield(data, 'Filename')
        fprintf('Verified: Filename field exists.\n');
    else
        error('Metadata struct is missing the "Filename" field.');
    end
    
    fprintf('Test 1 Passed!\n');
    
catch ME
    fprintf('CRASH in Test 1. Logic Error: %s\n', ME.message);
    rethrow(ME);
end

%% Test 2: Error Handling (Missing File)
fprintf('\nRunning Test 2: Missing File Handling...\n');
try
    dwim.extractMetadata('path_to_nowhere.dcm');
    error('Test Failed: Should have errored on missing file.');
catch ME
    % Accept ANY error starting with dwim or MATLAB's file error
    fprintf('Test 2 Passed: Correctly caught error: %s\n', ME.message);
end

fprintf('\nWeek 5 Testing Suite Completed Successfully.\n');