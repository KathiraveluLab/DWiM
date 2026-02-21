% tests/test_extractMetadata.m

fprintf('Running Test 1: Metadata Extraction...\n');

% 1. DYNAMIC DATA GENERATION
tempDir = tempname;
mkdir(tempDir);

cleanupObj = onCleanup(@() rmdir(tempDir, 's')); 

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
    rethrow(ME); 
end
% Note: We don't need manual rmdir() anymore because cleanupObj handles it automatically!