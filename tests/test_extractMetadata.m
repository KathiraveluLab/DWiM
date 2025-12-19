%% Test Suite for dwim.extractMetadata (Week 5: CI/CD Robustness)
clear; clc;

% --- STEP 1: ROBUST PATH SETUP ---
% Get the folder where this script is located (tests/)
testScriptDir = fileparts(mfilename('fullpath'));

% Construct the absolute path to the test file inside tests/
sampleFile = fullfile(testScriptDir, 'image01.dcm');

% --- STEP 2: VERIFICATION ---
% The file MUST exist now because we are pushing it to GitHub.
if ~isfile(sampleFile)
    error('CRITICAL: Test fixture "image01.dcm" is missing from tests/ folder.');
end

%% Test 1: Functional Metadata Extraction (Positive Test)
fprintf('Running Test 1: Real Metadata Extraction...\n');

% 1. Run the function
data = dwim.extractMetadata(sampleFile);

% 2. Verify Output Type
assert(isstruct(data), 'Output must be a struct.');

% 3. Verify Critical DICOM Tags
assert(isfield(data, 'Filename'), 'Metadata missing Filename.');
assert(isfield(data, 'Format'), 'Metadata missing Format.');
assert(isfield(data, 'Width'), 'Metadata missing Width.');
assert(isfield(data, 'Height'), 'Metadata missing Height.');

fprintf('Test 1 Passed: Successfully read metadata.\n');

%% Test 2: Error Handling (Negative Test)
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

fprintf('\nWeek 5 Testing Suite Completed Successfully.\n');