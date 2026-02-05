function test_resampleVolume()
%TEST_RESAMPLEVOLUME Basic tests for resampleVolume function
%
%   This function runs basic validation tests for the resampleVolume function
%   to ensure proper functionality and error handling.

    fprintf('Testing dwim.preprocess3d.resampleVolume...\n');
    fprintf('==========================================\n');
    
    % Test 1: Basic functionality with synthetic data
    fprintf('Test 1: Basic functionality... ');
    try
        testVolume = rand(64, 64, 32);
        [resampled, metadata] = dwim.preprocess3d.resampleVolume(testVolume, ...
            'TargetSpacing', 1.0, 'Verbose', false);
        
        assert(ndims(resampled) == 3, 'Output should be 3D');
        assert(isstruct(metadata), 'Metadata should be a structure');
        assert(isfield(metadata, 'originalSize'), 'Metadata should contain originalSize');
        assert(isfield(metadata, 'resampledSize'), 'Metadata should contain resampledSize');
        
        fprintf('PASSED\n');
    catch ME
        fprintf('FAILED: %s\n', ME.message);
    end
    
    % Test 2: Input validation - invalid volume
    fprintf('Test 2: Input validation (invalid volume)... ');
    try
        dwim.preprocess3d.resampleVolume(rand(64, 64), 'Verbose', false);
        fprintf('FAILED: Should have thrown error for 2D input\n');
    catch ME
        if strcmp(ME.identifier, 'dwim:resampleVolume:InvalidVolume')
            fprintf('PASSED\n');
        else
            fprintf('FAILED: Wrong error type: %s\n', ME.identifier);
        end
    end
    
    % Test 3: Input validation - invalid target spacing
    fprintf('Test 3: Input validation (invalid target spacing)... ');
    try
        testVolume = rand(32, 32, 16);
        dwim.preprocess3d.resampleVolume(testVolume, 'TargetSpacing', -1, 'Verbose', false);
        fprintf('FAILED: Should have thrown error for negative spacing\n');
    catch ME
        if strcmp(ME.identifier, 'dwim:resampleVolume:InvalidTargetSpacing')
            fprintf('PASSED\n');
        else
            fprintf('FAILED: Wrong error type: %s\n', ME.identifier);
        end
    end
    
    % Test 4: Input validation - invalid method
    fprintf('Test 4: Input validation (invalid method)... ');
    try
        testVolume = rand(32, 32, 16);
        dwim.preprocess3d.resampleVolume(testVolume, 'Method', 'invalid', 'Verbose', false);
        fprintf('FAILED: Should have thrown error for invalid method\n');
    catch ME
        if strcmp(ME.identifier, 'dwim:resampleVolume:InvalidMethod')
            fprintf('PASSED\n');
        else
            fprintf('FAILED: Wrong error type: %s\n', ME.identifier);
        end
    end
    
    % Test 5: Different interpolation methods
    fprintf('Test 5: Different interpolation methods... ');
    try
        testVolume = rand(32, 32, 16);
        methods = {'linear', 'cubic', 'nearest'};
        
        for i = 1:length(methods)
            [~, ~] = dwim.preprocess3d.resampleVolume(testVolume, ...
                'Method', methods{i}, 'TargetSpacing', 1.0, 'Verbose', false);
        end
        
        fprintf('PASSED\n');
    catch ME
        fprintf('FAILED: %s\n', ME.message);
    end
    
    % Test 6: Auto target spacing
    fprintf('Test 6: Auto target spacing... ');
    try
        testVolume = rand(32, 32, 16);
        [resampled, metadata] = dwim.preprocess3d.resampleVolume(testVolume, ...
            'VoxelSpacing', [1.0, 1.0, 2.0], 'Verbose', false);
        
        expectedSpacing = min([1.0, 1.0, 2.0]);
        assert(abs(metadata.targetSpacing - expectedSpacing) < 1e-6, ...
               'Auto spacing should use minimum of voxel spacings');
        
        fprintf('PASSED\n');
    catch ME
        fprintf('FAILED: %s\n', ME.message);
    end
    
    % Test 7: Data type preservation
    fprintf('Test 7: Data type preservation... ');
    try
        testVolume = uint16(rand(32, 32, 16) * 1000);
        originalClass = class(testVolume);
        
        [resampled, ~] = dwim.preprocess3d.resampleVolume(testVolume, ...
            'TargetSpacing', 1.0, 'Verbose', false);
        
        assert(strcmp(class(resampled), originalClass), ...
               'Output should preserve input data type');
        
        fprintf('PASSED\n');
    catch ME
        fprintf('FAILED: %s\n', ME.message);
    end
    
    % Test 8: Metadata completeness
    fprintf('Test 8: Metadata completeness... ');
    try
        testVolume = rand(32, 32, 16);
        [~, metadata] = dwim.preprocess3d.resampleVolume(testVolume, ...
            'TargetSpacing', 1.0, 'Verbose', false);
        
        requiredFields = {'originalSize', 'resampledSize', 'originalSpacing', ...
                         'targetSpacing', 'scaleFactor', 'method', 'processingTime'};
        
        for i = 1:length(requiredFields)
            assert(isfield(metadata, requiredFields{i}), ...
                   'Missing required metadata field: %s', requiredFields{i});
        end
        
        fprintf('PASSED\n');
    catch ME
        fprintf('FAILED: %s\n', ME.message);
    end
    
    % Test 9: Scale factor calculation
    fprintf('Test 9: Scale factor calculation... ');
    try
        testVolume = rand(32, 32, 16);
        voxelSpacing = [2.0, 2.0, 4.0];
        targetSpacing = 1.0;
        
        [~, metadata] = dwim.preprocess3d.resampleVolume(testVolume, ...
            'VoxelSpacing', voxelSpacing, 'TargetSpacing', targetSpacing, 'Verbose', false);
        
        expectedScaleFactor = voxelSpacing / targetSpacing;
        actualScaleFactor = metadata.scaleFactor;
        
        assert(all(abs(actualScaleFactor - expectedScaleFactor) < 1e-6), ...
               'Scale factor calculation incorrect');
        
        fprintf('PASSED\n');
    catch ME
        fprintf('FAILED: %s\n', ME.message);
    end
    
    % Test 10: Output size calculation
    fprintf('Test 10: Output size calculation... ');
    try
        inputSize = [32, 32, 16];
        testVolume = rand(inputSize);
        scaleFactor = [2, 2, 2];  % Double size in each dimension
        
        [resampled, ~] = dwim.preprocess3d.resampleVolume(testVolume, ...
            'VoxelSpacing', [2, 2, 2], 'TargetSpacing', 1.0, 'Verbose', false);
        
        expectedSize = round(inputSize .* scaleFactor);
        actualSize = size(resampled);
        
        assert(isequal(actualSize, expectedSize), ...
               'Output size calculation incorrect');
        
        fprintf('PASSED\n');
    catch ME
        fprintf('FAILED: %s\n', ME.message);
    end
    
    fprintf('==========================================\n');
    fprintf('Basic testing completed.\n');
    
    % Performance test with larger volume
    fprintf('\nPerformance test with larger volume...\n');
    try
        largeVolume = rand(128, 128, 64, 'single');
        tic;
        [~, metadata] = dwim.preprocess3d.resampleVolume(largeVolume, ...
            'TargetSpacing', 1.0, 'UseGPU', false, 'Verbose', true);
        
        fprintf('Processing time: %.2f seconds\n', metadata.processingTime);
        fprintf('Volume ratio: %.2f\n', metadata.volumeRatio);
        
    catch ME
        fprintf('Performance test failed: %s\n', ME.message);
    end
    
    fprintf('\nAll tests completed!\n');
end