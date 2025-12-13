function test_ct_lung()
%TEST_CT_LUNG Test resampling on CT lung series with realistic parameters
%
%   This test validates the resampleVolume function using CT lung-specific
%   parameters and validates voxel spacing calculations.

    rng('default'); % Seed the random number generator for reproducible tests
    fprintf('Testing CT Lung Series Resampling\n');
    fprintf('=================================\n');
    
    % Test 1: CT lung volume with realistic spacing
    fprintf('Test 1: CT lung volume with realistic spacing... ');
    try
        % Create realistic CT lung volume (512x512x300 typical)
        lungVolume = createCTLungVolume([256, 256, 150]);
        
        % Typical CT lung spacing: 0.7x0.7x1.25mm
        voxelSpacing = [0.7, 0.7, 1.25];
        targetSpacing = 1.0;  % Isotropic 1mm
        
        [resampled, metadata] = dwim.preprocess3d.resampleVolume(lungVolume, ...
            'VoxelSpacing', voxelSpacing, 'TargetSpacing', targetSpacing, ...
            'Method', 'linear', 'Verbose', false);
        
        % Validate voxel spacing calculation
        expectedScaleFactor = voxelSpacing / targetSpacing;
        actualScaleFactor = metadata.scaleFactor;
        
        assert(all(abs(actualScaleFactor - expectedScaleFactor) < 1e-6), ...
               'Voxel spacing calculation incorrect');
        
        % Check output dimensions
        inputSize = size(lungVolume);
        expectedSize = round(inputSize .* expectedScaleFactor);
        actualSize = size(resampled);
        
        assert(isequal(actualSize, expectedSize), ...
               'Output size calculation incorrect for CT lung');
        
        fprintf('PASSED\n');
    catch ME
        fprintf('FAILED: %s\n', ME.message);
    end
    
    % Test 2: Anisotropic to isotropic conversion
    fprintf('Test 2: Anisotropic to isotropic conversion... ');
    try
        lungVolume = createCTLungVolume([128, 128, 64]);
        
        % Highly anisotropic spacing (thin slice CT)
        voxelSpacing = [0.5, 0.5, 5.0];
        
        [resampled, metadata] = dwim.preprocess3d.resampleVolume(lungVolume, ...
            'VoxelSpacing', voxelSpacing, 'Verbose', false);
        
        % Should auto-select minimum spacing (0.5mm)
        assert(abs(metadata.targetSpacing - 0.5) < 1e-6, ...
               'Auto spacing should use minimum voxel spacing');
        
        % Z dimension should increase significantly
        assert(size(resampled, 3) > size(lungVolume, 3) * 8, ...
               'Z dimension should increase for thick slice correction');
        
        fprintf('PASSED\n');
    catch ME
        fprintf('FAILED: %s\n', ME.message);
    end
    
    % Test 3: Lung windowing preservation
    fprintf('Test 3: Lung windowing preservation... ');
    try
        lungVolume = createCTLungVolume([64, 64, 32]);
        
        % Apply lung windowing before resampling
        lungWindowed = dwim.preprocess.applyWindowPreset(lungVolume(:,:,16), 'lung');
        
        [resampled, ~] = dwim.preprocess3d.resampleVolume(lungVolume, ...
            'TargetSpacing', 1.0, 'Verbose', false);
        
        % Apply same windowing to resampled slice
        resampledWindowed = dwim.preprocess.applyWindowPreset(resampled(:,:,round(end/2)), 'lung');
        
        % Should preserve intensity characteristics
        assert(abs(mean(lungWindowed(:)) - mean(resampledWindowed(:))) < 0.1, ...
               'Lung windowing characteristics should be preserved');
        
        fprintf('PASSED\n');
    catch ME
        fprintf('FAILED: %s\n', ME.message);
    end
    
    % Test 4: Performance with large CT volume
    fprintf('Test 4: Performance with large CT volume... ');
    try
        largeLungVolume = createCTLungVolume([512, 512, 200]);
        
        tic;
        [resampled, metadata] = dwim.preprocess3d.resampleVolume(largeLungVolume, ...
            'VoxelSpacing', [0.7, 0.7, 1.25], 'TargetSpacing', 1.0, ...
            'UseGPU', false, 'Verbose', false);
        processingTime = toc;
        
        voxels = prod(size(largeLungVolume));
        rate = voxels / processingTime / 1e6;  % MVoxels/second
        
        fprintf('\n    Volume: [%d %d %d] -> [%d %d %d]\n', ...
                size(largeLungVolume), size(resampled));
        fprintf('    Processing: %.2f sec (%.1f MVox/s)\n', processingTime, rate);
        fprintf('  PASSED\n');
        
    catch ME
        fprintf('FAILED: %s\n', ME.message);
    end
    
    fprintf('=================================\n');
    fprintf('CT Lung testing completed.\n');
end

function lungVolume = createCTLungVolume(dimensions)
%CREATECTLUNGVOLUME Create realistic CT lung volume for testing
    [rows, cols, slices] = deal(dimensions(1), dimensions(2), dimensions(3));
    
    % Initialize with air (-1000 HU)
    lungVolume = -1000 * ones(rows, cols, slices, 'int16');
    
    % Create coordinate grids
    [X, Y, Z] = meshgrid(1:cols, 1:rows, 1:slices);
    centerX = cols/2; centerY = rows/2; centerZ = slices/2;
    
    % Add lung parenchyma (-800 to -600 HU)
    lungMask = ((X-centerX).^2/((cols*0.35)^2) + (Y-centerY).^2/((rows*0.4)^2)) < 1;
    lungVolume(lungMask) = -800 + 200 * rand(sum(lungMask(:)), 1);
    
    % Add some vessels and airways (-500 to 0 HU)
    vesselMask = ((X-centerX).^2/((cols*0.1)^2) + (Y-centerY).^2/((rows*0.1)^2)) < 1;
    lungVolume(vesselMask) = -500 + 500 * rand(sum(vesselMask(:)), 1);
    
    % Add chest wall and ribs (100 to 1000 HU)
    chestWall = ((X-centerX).^2/((cols*0.48)^2) + (Y-centerY).^2/((rows*0.48)^2)) > 0.8;
    lungVolume(chestWall) = 100 + 900 * rand(sum(chestWall(:)), 1);
    
    % Add some noise
    lungVolume = lungVolume + int16(50 * randn(size(lungVolume)));
end