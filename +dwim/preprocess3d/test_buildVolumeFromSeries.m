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

        fprintf('==============================\n');
        fprintf('All volume builder tests passed!\n');

    catch ME
        fprintf('FAILED: %s\n', ME.message);
        rethrow(ME);
    end

    % Cleanup
    rmdir(tempDir, 's');
end

function tempDir = createSyntheticDicomSeries()
%CREATESYNTHETICDICOMSERIES Create temporary directory with fake DICOM files

    % DICOM UID constants
    CT_IMAGE_STORAGE_UID = '1.2.840.10008.5.1.4.1.1.2';
    EXPLICIT_VR_LE_UID = '1.2.840.10008.1.2.1';

    % Create temp directory
    tempDir = fullfile(tempdir, sprintf('dwiM_test_%d', randi(10000)));
    mkdir(tempDir);

    % Create synthetic DICOM files
    numSlices = 10;
    rows = 64;
    cols = 64;
    sliceSpacing = 5.0;

    % Generate series-level UIDs once (shared across all slices)
    studyUID = dicomuid();
    seriesUID = dicomuid();

    for i = 1:numSlices
        % Create DICOM info structure
        info = struct();
        info.PatientName = 'Test Patient';
        info.StudyInstanceUID = studyUID;
        info.SeriesInstanceUID = seriesUID;
        info.SOPInstanceUID = dicomuid();
        info.SOPClassUID = CT_IMAGE_STORAGE_UID; % CT Image Storage
        info.MediaStorageSOPClassUID = info.SOPClassUID;
        info.MediaStorageSOPInstanceUID = info.SOPInstanceUID;
        info.TransferSyntaxUID = EXPLICIT_VR_LE_UID; % Explicit VR Little Endian
        info.ImplementationClassUID = CT_IMAGE_STORAGE_UID;
        info.StudyDescription = 'Test Study';
        info.SeriesDescription = 'Test Series';
        info.Modality = 'CT';
        info.Rows = rows;
        info.Columns = cols;
        info.BitsAllocated = 16;
        info.BitsStored = 16;
        info.HighBit = 15;
        info.PixelRepresentation = 1; % signed
        info.SamplesPerPixel = 1;
        info.PhotometricInterpretation = 'MONOCHROME2';
        info.PixelSpacing = [1.0, 1.0];
        info.SliceThickness = sliceSpacing;
        info.ImagePositionPatient = [0, 0, (i-1) * sliceSpacing];
        info.ImageOrientationPatient = [1, 0, 0, 0, 1, 0];
        info.RescaleIntercept = -1024;
        info.RescaleSlope = 1;
        info.RescaleType = 'HU';

        % Create synthetic image data
        imageData = int16(-1000 + 2000 * rand(rows, cols));  % CT-like HU values

        % Save as DICOM
        filename = sprintf('slice_%03d.dcm', i);
        filepath = fullfile(tempDir, filename);

        dicomwrite(imageData, filepath, info, 'CreateMode', 'copy');
    end
end