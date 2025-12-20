function test_validateVolumeForML()
%TEST_VALIDATEVOLUMEFORML Test volume validation for ML workflows
%
%   This test validates the validateVolumeForML function using synthetic
%   medical volumes and edge cases.

    rng('default'); % Reset RNG for reproducible tests
    fprintf('Testing Volume Validation for ML Workflows\n');
    fprintf('=========================================\n');

    % Test 1: Valid CT lung volume
    fprintf('Test 1: Valid CT lung volume... ');
    try
        lungVolume = createCTLungVolume([128, 128, 64]);

        [isValid, info] = dwim.preprocess3d.validateVolumeForML(lungVolume);

        assert(isValid, 'Valid lung volume should pass validation');
        assert(strcmp(info.assessment, 'Volume is ready for ML workflows'), ...
               'Assessment should indicate readiness');

        fprintf('PASSED\n');
        fprintf('  Dimensions: [%d %d %d]\n', info.dimensions);
        fprintf('  Assessment: %s\n', info.assessment);

    catch ME
        fprintf('FAILED: %s\n', ME.message);
    end

    % Test 2: Too small volume
    fprintf('Test 2: Too small volume... ');
    try
        smallVolume = createCTLungVolume([32, 32, 3]);

        [isValid, info] = dwim.preprocess3d.validateVolumeForML(smallVolume);

        assert(~isValid, 'Too small volume should fail validation');
        assert(~isempty(info.issues), 'Should have issues listed');

        fprintf('PASSED\n');
        fprintf('  Issues: %s\n', strjoin(info.issues, '; '));

    catch ME
        fprintf('FAILED: %s\n', ME.message);
    end

    % Test 3: Volume with NaN values
    fprintf('Test 3: Volume with NaN values... ');
    try
        lungVolume = single(createCTLungVolume([64, 64, 32]));
        lungVolume(10, 10, 5) = NaN;  % Add NaN value

        [isValid, info] = dwim.preprocess3d.validateVolumeForML(lungVolume);

        assert(~isValid, 'Volume with NaN should fail validation');
        assert(info.numNaN == 1, 'Should detect exactly 1 NaN');

        fprintf('PASSED\n');
        fprintf('  Detected %d NaN values\n', info.numNaN);

    catch ME
        fprintf('FAILED: %s\n', ME.message);
    end

    % Test 4: Large volume memory check
    fprintf('Test 4: Large volume memory check... ');
    try
        largeVolume = createCTLungVolume([512, 512, 200]);

        [isValid, info] = dwim.preprocess3d.validateVolumeForML(largeVolume, 'MemoryLimitGB', 0.05);

        assert(~isValid || ~isempty(info.warnings), 'Large volume should trigger warnings');
        assert(info.memoryUsageGB > 0.05, 'Should calculate memory usage correctly');

        fprintf('PASSED\n');
        fprintf('  Memory usage: %.2f GB\n', info.memoryUsageGB);

    catch ME
        fprintf('FAILED: %s\n', ME.message);
    end

    % Test 5: Anisotropic volume
    fprintf('Test 5: Anisotropic volume... ');
    try
        % Create very thin slices (anisotropic)
        anisotropicVolume = createCTLungVolume([256, 256, 10]);

        [isValid, info] = dwim.preprocess3d.validateVolumeForML(anisotropicVolume);

        assert(isValid, 'Anisotropic volume should still be valid');
        assert(length(info.aspectRatios) == 3, 'Should calculate aspect ratios');

        fprintf('PASSED\n');
        fprintf('  Aspect ratios [XY, XZ, YZ]: [%.2f, %.2f, %.2f]\n', info.aspectRatios);

    catch ME
        fprintf('FAILED: %s\n', ME.message);
    end

    fprintf('=========================================\n');
    fprintf('Volume validation testing completed.\n');
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