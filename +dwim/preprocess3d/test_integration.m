function test_integration()
%TEST_INTEGRATION Integration tests for 3D preprocessing module
%
%   This function runs integration tests combining multiple functions
%   from the preprocess3d module to validate end-to-end workflows.

    fprintf('DWiM 3D Preprocessing Integration Tests\n');
    fprintf('======================================\n');
    
    % Test 1: Complete 3D preprocessing workflow
    fprintf('Test 1: Complete 3D preprocessing workflow... ');
    try
        % Create synthetic 3D volume
        volume = createSyntheticVolume([64, 64, 32], 'CT');
        
        % Step 1: Resample to isotropic spacing
        [resampled, resampleMeta] = dwim.preprocess3d.resampleVolume(volume, ...
            'VoxelSpacing', [1.0, 1.0, 2.0], 'TargetSpacing', 1.0, 'Verbose', false);
        
        % Step 2: Apply 2D preprocessing to each slice
        processed = zeros(size(resampled));
        for slice = 1:size(resampled, 3)
            processed(:,:,slice) = dwim.preprocess.normalizeHU(resampled(:,:,slice), 0, 1000);
        end
        
        % Validate results
        assert(ndims(processed) == 3, 'Output should be 3D');
        assert(all(processed(:) >= 0) && all(processed(:) <= 1), 'Values should be normalized');
        
        fprintf('PASSED\n');
    catch ME
        fprintf('FAILED: %s\n', ME.message);
    end
    
    % Test 2: Memory management with large volume
    fprintf('Test 2: Memory management with large volume... ');
    try
        largeVolume = createSyntheticVolume([256, 256, 128], 'CT');
        
        [resampled, metadata] = dwim.preprocess3d.resampleVolume(largeVolume, ...
            'TargetSpacing', 0.5, 'MaxMemoryGB', 1.0, 'Verbose', false);
        
        assert(ndims(resampled) == 3, 'Output should be 3D');
        assert(isfield(metadata, 'usedChunkedProcessing'), 'Should report chunked processing');
        
        fprintf('PASSED\n');
    catch ME
        fprintf('FAILED: %s\n', ME.message);
    end
    
    % Test 3: Different data types
    fprintf('Test 3: Different data types... ');
    try
        dataTypes = {'uint8', 'uint16', 'int16', 'single', 'double'};
        
        for i = 1:length(dataTypes)
            volume = createSyntheticVolume([32, 32, 16], 'CT', dataTypes{i});
            originalClass = class(volume);
            
            [resampled, ~] = dwim.preprocess3d.resampleVolume(volume, ...
                'TargetSpacing', 1.0, 'Verbose', false);
            
            assert(strcmp(class(resampled), originalClass), ...
                   'Data type should be preserved for %s', dataTypes{i});
        end
        
        fprintf('PASSED\n');
    catch ME
        fprintf('FAILED: %s\n', ME.message);
    end
    
    % Test 4: Performance benchmarking
    fprintf('Test 4: Performance benchmarking... ');
    try
        volumes = {
            createSyntheticVolume([64, 64, 32], 'CT'),
            createSyntheticVolume([128, 128, 64], 'CT'),
            createSyntheticVolume([256, 256, 128], 'CT')
        };
        
        sizes = {'Small (64³)', 'Medium (128³)', 'Large (256³)'};
        
        for i = 1:length(volumes)
            tic;
            [~, metadata] = dwim.preprocess3d.resampleVolume(volumes{i}, ...
                'TargetSpacing', 1.0, 'UseGPU', false, 'Verbose', false);
            processingTime = toc;
            
            voxels = prod(size(volumes{i}));
            rate = voxels / processingTime / 1e6;  % MVoxels/second
            
            fprintf('\n    %s: %.3f sec (%.1f MVox/s)', sizes{i}, processingTime, rate);
        end
        
        fprintf('\n  PASSED\n');
    catch ME
        fprintf('FAILED: %s\n', ME.message);
    end
    
    % Test 5: Error handling and recovery
    fprintf('Test 5: Error handling and recovery... ');
    try
        % Test invalid inputs
        try
            dwim.preprocess3d.resampleVolume(rand(64, 64), 'Verbose', false);
            assert(false, 'Should have failed for 2D input');
        catch ME
            assert(contains(ME.identifier, 'InvalidVolume'), 'Wrong error type');
        end
        
        % Test invalid parameters
        try
            dwim.preprocess3d.resampleVolume(rand(32,32,16), 'TargetSpacing', -1, 'Verbose', false);
            assert(false, 'Should have failed for negative spacing');
        catch ME
            assert(contains(ME.identifier, 'InvalidTargetSpacing'), 'Wrong error type');
        end
        
        fprintf('PASSED\n');
    catch ME
        fprintf('FAILED: %s\n', ME.message);
    end
    
    % Test 6: Integration with existing preprocessing
    fprintf('Test 6: Integration with existing preprocessing... ');
    try
        volume = createSyntheticVolume([64, 64, 32], 'CT');
        
        % Resample volume
        [resampled, ~] = dwim.preprocess3d.resampleVolume(volume, ...
            'TargetSpacing', 1.0, 'Verbose', false);
        
        % Apply existing 2D preprocessing functions
        slice = resampled(:,:,16);  % Middle slice
        
        % Test all existing preprocessing functions
        [isValid, ~] = dwim.preprocess.validateImageForML(slice);
        assert(isValid, 'Resampled slice should be valid for ML');
        
        normalized = dwim.preprocess.normalizeHU(slice, -500, 1500);
        assert(all(normalized(:) >= 0) && all(normalized(:) <= 1), 'Should be normalized');
        
        windowed = dwim.preprocess.applyWindowPreset(slice, 'lung');
        assert(all(windowed(:) >= 0) && all(windowed(:) <= 1), 'Should be windowed');
        
        fprintf('PASSED\n');
    catch ME
        fprintf('FAILED: %s\n', ME.message);
    end
    
    % Test 7: Stress test with extreme parameters
    fprintf('Test 7: Stress test with extreme parameters... ');
    try
        volume = createSyntheticVolume([32, 32, 16], 'CT');
        
        % Very small target spacing (large upsampling)
        [upsampled, meta1] = dwim.preprocess3d.resampleVolume(volume, ...
            'VoxelSpacing', [2, 2, 2], 'TargetSpacing', 0.1, 'Verbose', false);
        assert(meta1.volumeRatio > 1000, 'Should be large upsampling');
        
        % Very large target spacing (large downsampling)
        [downsampled, meta2] = dwim.preprocess3d.resampleVolume(volume, ...
            'VoxelSpacing', [0.5, 0.5, 0.5], 'TargetSpacing', 5.0, 'Verbose', false);
        assert(meta2.volumeRatio < 0.01, 'Should be large downsampling');
        
        fprintf('PASSED\n');
    catch ME
        fprintf('FAILED: %s\n', ME.message);
    end
    
    fprintf('======================================\n');
    fprintf('Integration testing completed.\n');
    
    % Performance summary
    fprintf('\nPerformance Summary:\n');
    runPerformanceSummary();
end

function volume = createSyntheticVolume(dimensions, modality, dataType)
%CREATESYNTHETICVOLUME Create synthetic medical volume for testing
    if nargin < 3
        dataType = 'double';
    end
    
    [rows, cols, slices] = deal(dimensions(1), dimensions(2), dimensions(3));
    
    switch modality
        case 'CT'
            % Create CT-like volume with realistic HU values
            volume = randn(rows, cols, slices) * 100;  % Noise
            
            % Add some structures
            [X, Y, Z] = meshgrid(1:cols, 1:rows, 1:slices);
            centerX = cols/2; centerY = rows/2; centerZ = slices/2;
            
            % Add a sphere (organ)
            sphere = sqrt((X-centerX).^2 + (Y-centerY).^2 + (Z-centerZ).^2) < min(dimensions)/4;
            volume(sphere) = volume(sphere) + 50;  % Soft tissue
            
            % Add some high-density structures (bone)
            bone = sqrt((X-centerX).^2 + (Y-centerY).^2) < min(dimensions)/8;
            volume(bone) = volume(bone) + 200;
            
            % Shift to realistic HU range
            volume = volume - 1000;  % Air baseline
            
        case 'MRI'
            % Create MRI-like volume
            volume = rand(rows, cols, slices) * 1000;
            
        otherwise
            volume = rand(rows, cols, slices) * 1000;
    end
    
    % Convert to specified data type
    switch dataType
        case 'uint8'
            volume = uint8(max(0, min(255, volume + 128)));
        case 'uint16'
            volume = uint16(max(0, min(65535, volume + 32768)));
        case 'int16'
            volume = int16(max(-32768, min(32767, volume)));
        case 'single'
            volume = single(volume);
        case 'double'
            volume = double(volume);
    end
end

function runPerformanceSummary()
%RUNPERFORMANCESUMMARY Run performance tests and display summary
    fprintf('Running performance benchmarks...\n');
    
    % Test different volume sizes
    sizes = [32, 64, 128];
    methods = {'linear', 'cubic', 'nearest'};
    
    fprintf('Volume Size | Method  | Time (s) | Rate (MVox/s)\n');
    fprintf('------------|---------|----------|-------------\n');
    
    for i = 1:length(sizes)
        volume = rand(sizes(i), sizes(i), sizes(i)/2, 'single');
        voxels = prod(size(volume));
        
        for j = 1:length(methods)
            tic;
            dwim.preprocess3d.resampleVolume(volume, ...
                'Method', methods{j}, 'TargetSpacing', 1.0, ...
                'UseGPU', false, 'Verbose', false);
            time = toc;
            rate = voxels / time / 1e6;
            
            fprintf('%3d³       | %-7s | %8.3f | %11.1f\n', ...
                    sizes(i), methods{j}, time, rate);
        end
    end
end