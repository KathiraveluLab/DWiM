
% Path: C:\Users\surya\DWiM\tests\test_extractMetadata.m

%% Test 1: Functional Metadata Extraction
fprintf('Running Test 1: Metadata Extraction...\n');

% 1. DYNAMIC DATA GENERATION (Replaces the deleted hardcoded image)
% Create a temporary directory and file path
tempDir = tempname;
mkdir(tempDir);
tempDicomPath = fullfile(tempDir, 'dummy_test_image.dcm');

% Create a fake 10x10 image with basic metadata
dummyImg = uint8(zeros(10, 10));
dicomwrite(dummyImg, tempDicomPath, 'PatientName', 'Test^Patient', 'PatientID', 'ID123');

fprintf('Targeting temporary test file at: %s\n', tempDicomPath);

try
    % 2. EXECUTE LOGIC
    data = dwim.extractMetadata(tempDicomPath);
    
    % 3. VERIFY
    assert(isstruct(data), 'Output must be a struct.');
    fprintf('Test 1 Passed: Structure received.\n');
    
catch ME
    fprintf('ERROR in dwim.extractMetadata: %s\n', ME.message);
    % Clean up before re-throwing so we don't leave orphaned files
    rmdir(tempDir, 's');
    rethrow(ME); 
end

% 4. CLEANUP
% Remove the temporary folder and dummy file after the test finishes
rmdir(tempDir, 's');