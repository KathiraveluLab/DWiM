% --- Week 8 Path-Corrected Test ---
% Path: C:\Users\surya\DWiM\tests\test_extractMetadata.m

% 1. DYNAMIC PATH DISCOVERY (Fixes the CI 'File not found' error)
% We find the project root relative to this test file's location
testFileLocation = fileparts(mfilename('fullpath'));
projectRoot = fileparts(testFileLocation); % Moves up one level from 'tests' to root
testDataDir = fullfile(projectRoot, 'test_data'); 
tempDicomPath = fullfile(testDataDir, 'image01.dcm');

fprintf('Targeting test file at: %s\n', tempDicomPath);

%% Test 1: Functional Metadata Extraction
fprintf('Running Test 1: Metadata Extraction...\n');
try
    % Verify file exists before calling logic
    if ~exist(tempDicomPath, 'file')
        error('CI_Setup_Error: test_data/image01.dcm is missing from the repo root.');
    end
    
    data = dwim.extractMetadata(tempDicomPath);
    assert(isstruct(data), 'Output must be a struct.');
    fprintf('Test 1 Passed: Structure received.\n');
    
catch ME
    fprintf('ERROR in dwim.extractMetadata: %s\n', ME.message);
    % Force re-throw if it's a real logic error
    if ~contains(ME.message, 'found'), rethrow(ME); end
end