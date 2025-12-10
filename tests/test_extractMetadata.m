%% Test Suite for dwim.extractMetadata (Week 4: Functional Validation)
clear; clc;

% --- STEP 1: ROBUST PATH SETUP ---
% Get the folder where this script is located (tests/)
testScriptDir = fileparts(mfilename('fullpath'));
% Go up one level to the repository root (DWiM/)
repoRoot = fileparts(testScriptDir);
% Construct the absolute path to the test file
sampleFile = fullfile(repoRoot, 'image01.dcm');

% --- STEP 2: SELF-HEALING LOGIC 
% If the file is missing (e.g., on a fresh CI runner), create it.
if ~isfile(sampleFile)
    fprintf('Test fixture missing. Auto-creating dummy DICOM at %s...\n', sampleFile);
    try
        % Create a valid 10x10 dummy DICOM
        dicomwrite(uint8(zeros(10, 10)), sampleFile);
    catch ME
        error('Failed to auto-create test data. Reason: %s', ME.message);
    end
end

%% Test 1: Functional Metadata Extraction (Positive Test)
fprintf('Running Test 1: Real Metadata Extraction...\n');

% 1. Run the function
data = dwim.extractMetadata(sampleFile);

% 2. Verify Output Type
assert(isstruct(data), 'Output must be a struct.');

% 3. Verify Critical DICOM Tags (Fixes Bot "Coverage" Error)
% Since this is a dummy file, we check for standard file attributes
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

fprintf('\nWeek 4 Testing Suite Completed Successfully.\n');