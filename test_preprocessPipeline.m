% Test script for dwim.preprocessPipeline
% This script creates synthetic test data and runs the preprocessing pipeline

fprintf('Starting preprocessPipeline tests...\n');

%% Test 1: Single CT slice (2D image)
fprintf('\n=== Test 1: Single CT Slice ===\n');

% Create synthetic single CT slice (512x512 with HU values)
singleSlice = randi([-1000, 3000], 512, 512);

% Configure pipeline for 2D processing
config = struct();
config.inputType = 'image';
config.outputType = 'image';
config.steps = {'validate', 'window', 'normalize'};
config.parameters.window.preset = 'lung';
config.parameters.normalize = struct('windowCenter', -600, 'windowWidth', 1500);
config.verbose = true;

try
    [output1, meta1] = dwim.preprocessPipeline(singleSlice, config);
    fprintf('✓ Single slice test passed\n');
    fprintf('  Input size: %s\n', mat2str(size(singleSlice)));
    fprintf('  Output size: %s\n', mat2str(size(output1)));
    fprintf('  Processing time: %.2f seconds\n', meta1.totalTime);
catch ME
    fprintf('✗ Single slice test failed: %s\n', ME.message);
end

%% Test 2: Multi-slice CT volume (3D)
fprintf('\n=== Test 2: Multi-slice CT Volume ===\n');

% Create synthetic CT volume (512x512x10 with HU values)
volume = randi([-1000, 3000], 512, 512, 10);

% Configure pipeline for 3D processing
config = struct();
config.inputType = 'volume';
config.outputType = 'volume';
config.steps = {'assemble', 'orient', 'resample', 'validate_volume'};
config.parameters.orient.targetOrientation = 'RAS';
config.parameters.resample.targetSpacing = [1.0, 1.0, 1.0];
config.verbose = true;

try
    [output2, meta2] = dwim.preprocessPipeline(volume, config);
    fprintf('✓ Volume test passed\n');
    fprintf('  Input size: %s\n', mat2str(size(volume)));
    fprintf('  Output size: %s\n', mat2str(size(output2)));
    fprintf('  Processing time: %.2f seconds\n', meta2.totalTime);
catch ME
    fprintf('✗ Volume test failed: %s\n', ME.message);
end

%% Test 3: Edge case - Empty input
fprintf('\n=== Test 3: Edge Case - Empty Input ===\n');

try
    config.inputType = 'image';
    config.steps = {'validate'};
    [output3, meta3] = dwim.preprocessPipeline([], config);
    fprintf('✗ Empty input test should have failed but passed\n');
catch ME
    fprintf('✓ Empty input test correctly failed: %s\n', ME.identifier);
end

%% Test 4: Edge case - Invalid step
fprintf('\n=== Test 4: Edge Case - Invalid Step ===\n');

config.inputType = 'image';
config.steps = {'invalid_step'};
config.verbose = false;

try
    [output4, meta4] = dwim.preprocessPipeline(singleSlice, config);
    fprintf('✓ Invalid step test passed (warning expected)\n');
catch ME
    fprintf('✗ Invalid step test failed: %s\n', ME.message);
end

%% Test 5: Edge case - Empty DICOM directory
fprintf('\n=== Test 5: Edge Case - Empty DICOM Directory ===\n');

% Create temporary empty directory
tempDir = tempname;
mkdir(tempDir);

config.inputType = 'dicomdir';
config.steps = {'validate'};
config.verbose = false;

try
    [output5, meta5] = dwim.preprocessPipeline(tempDir, config);
    fprintf('✗ Empty directory test should have failed but passed\n');
catch ME
    if strcmp(ME.identifier, 'dwim:preprocessPipeline:EmptyVolume')
        fprintf('✓ Empty directory test correctly failed: %s\n', ME.identifier);
    else
        fprintf('✗ Empty directory test failed with unexpected error: %s\n', ME.identifier);
    end
end

% Clean up
rmdir(tempDir);

%% Test 6: Edge case - Wrong spacing (unusual values)
fprintf('\n=== Test 6: Edge Case - Unusual Spacing ===\n');

% Test with unusual spacing values
config.inputType = 'volume';
config.outputType = 'volume';
config.steps = {'resample'};
config.parameters.resample.targetSpacing = [0.005, 0.005, 0.005]; % Very small spacing
config.verbose = false;

% Capture warnings
warningState = warning('query');
warning('on', 'dwim:resampleVolume:UnusualSpacing');

try
    [output6, meta6] = dwim.preprocessPipeline(volume, config);
    fprintf('✓ Unusual spacing test passed (warning expected)\n');
catch ME
    fprintf('✗ Unusual spacing test failed: %s\n', ME.message);
end

% Restore warning state
warning(warningState);

fprintf('\n=== Test Summary ===\n');
fprintf('All tests completed. Check output above for results.\n');