% Test suite for dwim.convertToPNG
% Run with: runtests('tests/test_convertToPNG.m')

%% Setup - Create test DICOM file
testDir = fullfile(pwd, 'test_output');
if ~exist(testDir, 'dir'), mkdir(testDir); end

% Use existing test DICOM or create synthetic one
testDicomPath = fullfile(pwd, 'tests', 'image01.dcm');
if ~exist(testDicomPath, 'file')
    testDicomPath = fullfile(pwd, 'image01.dcm');
end

%% Test 1: Basic Conversion
fprintf('Test 1: Basic PNG Conversion...\n');
try
    outputPath = dwim.convertToPNG(testDicomPath, testDir);
    
    assert(isfile(outputPath), 'Output PNG file should exist');
    assert(endsWith(outputPath, '.png'), 'Output should be PNG');
    
    % Verify it's a valid image
    imgOut = imread(outputPath);
    assert(~isempty(imgOut), 'Output image should not be empty');
    
    fprintf('  ✓ Passed: PNG created at %s\n', outputPath);
catch ME
    fprintf('  ✗ Failed: %s\n', ME.message);
end

%% Test 2: 16-bit Output
fprintf('Test 2: 16-bit PNG Output...\n');
try
    outputPath = dwim.convertToPNG(testDicomPath, testDir, ...
        BitDepth=16, OutputName='test_16bit');
    
    info = imfinfo(outputPath);
    assert(info.BitDepth == 16, 'Output should be 16-bit');
    
    fprintf('  ✓ Passed: 16-bit PNG created\n');
catch ME
    fprintf('  ✗ Failed: %s\n', ME.message);
end

%% Test 3: Custom Windowing
fprintf('Test 3: Custom Window/Level...\n');
try
    outputPath = dwim.convertToPNG(testDicomPath, testDir, ...
        WindowCenter=128, WindowWidth=256, OutputName='test_windowed');
    
    assert(isfile(outputPath), 'Windowed PNG should exist');
    fprintf('  ✓ Passed: Custom windowing applied\n');
catch ME
    fprintf('  ✗ Failed: %s\n', ME.message);
end

%% Test 4: Missing File Error
fprintf('Test 4: Missing File Error Handling...\n');
try
    dwim.convertToPNG('nonexistent_file.dcm', testDir);
    fprintf('  ✗ Failed: Should have thrown error\n');
catch ME
    if contains(ME.identifier, 'FileNotFound')
        fprintf('  ✓ Passed: Correct error thrown\n');
    else
        fprintf('  ✗ Failed: Wrong error type: %s\n', ME.identifier);
    end
end

%% Test 5: Auto-create Output Directory
fprintf('Test 5: Auto-create Output Directory...\n');
try
    newDir = fullfile(testDir, 'auto_created_dir');
    if exist(newDir, 'dir'), rmdir(newDir, 's'); end
    
    outputPath = dwim.convertToPNG(testDicomPath, newDir, OutputName='auto_test');
    
    assert(isfolder(newDir), 'Directory should be auto-created');
    assert(isfile(outputPath), 'PNG should exist in new directory');
    
    fprintf('  ✓ Passed: Directory auto-created\n');
catch ME
    fprintf('  ✗ Failed: %s\n', ME.message);
end

%% Cleanup
fprintf('\n--- Cleaning up test files ---\n');
if exist(testDir, 'dir')
    rmdir(testDir, 's');
    fprintf('Removed test output directory.\n');
end

fprintf('\n=== convertToPNG Test Suite Complete ===\n');
