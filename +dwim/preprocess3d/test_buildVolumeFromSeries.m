function test_buildVolumeFromSeries()
%TEST_BUILDVOLUMEFROMSERIES Test the complete volume building pipeline
%
%   This test validates buildVolumeFromSeries with synthetic DICOM data

    fprintf('Testing Volume Builder Pipeline\n');
    fprintf('==============================\n');

    % Create temporary directory with synthetic DICOM files
    tempDir = createSyntheticDicomSeries();

    try
        % Test 1: Full pipeline
        fprintf('Test 1: Full pipeline processing... ');
        [volume, spacing, metadata] = dwim.preprocess3d.buildVolumeFromSeries(tempDir, ...
            'Verbose', false);

        % Validate results
        assert(~isempty(volume), 'Volume should not be empty');
        assert(length(spacing) == 3, 'Spacing should be 3D');
        assert(all(spacing > 0), 'Spacing values should be positive');
        assert(isstruct(metadata), 'Metadata should be a struct');

        % Check volume properties
        assert(ndims(volume) == 3, 'Volume should be 3D');
        assert(size(volume, 3) >= 5, 'Should have multiple slices');

        fprintf('PASSED\n');

        % Test 2: Custom settings
        fprintf('Test 2: Custom orientation and spacing... ');
        [volume2, spacing2, metadata2] = dwim.preprocess3d.buildVolumeFromSeries(tempDir, ...
            'TargetOrientation', 'LPS', ...
            'TargetSpacing', 2.0, ...
            'Verbose', false);

        assert(strcmp(metadata2.orientationCorrection.targetOrientation, 'LPS'), ...
               'Should use LPS orientation');
        assert(all(abs(spacing2 - 2.0) < 0.1), 'Should use 2mm spacing');

        fprintf('PASSED\n');

        % Test 3: Minimal processing
        fprintf('Test 3: Minimal processing (no correction/resampling)... ');
        [volume3, spacing3, metadata3] = dwim.preprocess3d.buildVolumeFromSeries(tempDir, ...
            'CorrectOrientation', false, ...
            'Resample', false, ...
            'Validate', false, ...
            'Verbose', false);

        assert(~metadata3.orientationCorrection.applied, 'Orientation correction should be disabled');
        assert(~metadata3.resampling.applied, 'Resampling should be disabled');

        fprintf('PASSED\n');

        % Test 4: Validation enabled
        fprintf('Test 4: With validation... ');
        [volume4, spacing4, metadata4] = dwim.preprocess3d.buildVolumeFromSeries(tempDir, ...
            'Validate', true, 'Verbose', false);

        assert(metadata4.validation.performed, 'Validation should be performed');
        assert(isfield(metadata4.validation, 'isValid'), 'Validation should have results');

        fprintf('PASSED\n');

        % Test 5: Edge case - Non-CT modality
        fprintf('Test 5: Edge case - Non-CT modality... ');
        tempDirMR = createSyntheticDicomSeries('Modality', 'MR');

        try
            [volume5, spacing5, metadata5] = dwim.preprocess3d.buildVolumeFromSeries(tempDirMR, ...
                'Verbose', false);
            fprintf('FAILED - Should have thrown error for non-CT modality\n');
            assert(false, 'Should have failed for non-CT modality');
        catch ME
            if strcmp(ME.identifier, 'dwim:buildVolumeFromSeries:NonCTModality')
                fprintf('PASSED - Correctly rejected non-CT modality\n');
            else
                fprintf('FAILED - Unexpected error: %s\n', ME.identifier);
                rethrow(ME);
            end
        end

        % Cleanup MR directory
        rmdir(tempDirMR, 's');

        fprintf('==============================\n');
        fprintf('All volume builder tests passed!\n');

    catch ME
        fprintf('FAILED: %s\n', ME.message);
        rethrow(ME);
    end

    % Cleanup
    rmdir(tempDir, 's');
end

function tempDir = createSyntheticDicomSeries(varargin)
%CREATESYNTHETICDICOMSERIES Create temporary directory with fake DICOM files

    % Parse arguments
    p = inputParser;
    addParameter(p, 'Modality', 'CT', @ischar);
    parse(p, varargin{:});
    modality = p.Results.Modality;

    % Create temp directory
    tempDir = fullfile(tempdir, sprintf('dwiM_test_%d', randi(10000)));
    mkdir(tempDir);

    % Create synthetic DICOM files
    numSlices = 10;
    rows = 64;
    cols = 64;

    for i = 1:numSlices
        % Create fake DICOM info
        info = struct();
        info.ImagePositionPatient = [0, 0, (i-1) * 5.0];  % 5mm spacing
        info.ImageOrientationPatient = [1, 0, 0, 0, 1, 0];  % Axial
        info.PixelSpacing = [1.0, 1.0];
        info.SliceThickness = 5.0;
        info.PatientName = 'Test^Patient';
        info.StudyDescription = 'Test Study';
        info.Modality = modality;

        % Create synthetic image data
        imageData = uint16(1000 + 500 * rand(rows, cols));  % CT-like values

        % Save as DICOM
        filename = sprintf('slice_%03d.dcm', i);
        filepath = fullfile(tempDir, filename);

        % For testing, we'll create a minimal DICOM-like file
        % In real scenarios, use dicomwrite
        save(filepath, 'imageData', 'info');
    end
end