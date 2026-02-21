function [volume, spacing, metadata] = buildVolumeFromSeries(dicomPath, varargin)
%BUILDVOLUMEFROMSERIES Build 3D volume from DICOM series with preprocessing
%
%   [volume, spacing, metadata] = buildVolumeFromSeries(dicomPath)
%       Builds 3D volume from DICOM files with automatic orientation correction
%       and isotropic resampling
%
%   [volume, spacing, metadata] = buildVolumeFromSeries(dicomPath, 'CorrectOrientation', false)
%       Builds volume without orientation correction
%
%   [volume, spacing, metadata] = buildVolumeFromSeries(dicomPath, 'Resample', false)
%       Builds volume without resampling
%
%   Inputs:
%       dicomPath - Path to directory containing DICOM series
%
%   Name-Value Arguments:
%       CorrectOrientation - Apply orientation correction (default: true)
%       TargetOrientation - Target orientation ('RAS', 'LPS', 'LAS') (default: 'RAS')
%       Resample - Apply isotropic resampling (default: true)
%       TargetSpacing - Target isotropic spacing in mm (default: auto)
%       Validate - Run validation checks (default: true)
%       Verbose - Display progress information (default: true)
%
%   Outputs:
%       volume - Processed 3D volume
%       spacing - Final voxel spacing [x,y,z] in mm
%       metadata - Structure with processing information
%
%   Example:
%       % Basic usage with all preprocessing
%       [volume, spacing, info] = dwim.preprocess3d.buildVolumeFromSeries('dicom_folder/');
%
%       % Custom settings
%       [volume, spacing, info] = dwim.preprocess3d.buildVolumeFromSeries('dicom_folder/', ...
%           'TargetOrientation', 'LPS', 'TargetSpacing', 1.0, 'Verbose', false);

    % Input validation
    arguments
        dicomPath (1,1) string
    end

    arguments (Repeating)
        varargin
    end

    % Parse arguments
    p = inputParser;
    addParameter(p, 'CorrectOrientation', true, @islogical);
    addParameter(p, 'TargetOrientation', 'RAS', @(x) ismember(x, {'RAS', 'LPS', 'LAS'}));
    addParameter(p, 'Resample', true, @islogical);
    addParameter(p, 'TargetSpacing', [], @(x) isempty(x) || (isscalar(x) && x > 0));
    addParameter(p, 'Validate', true, @islogical);
    addParameter(p, 'Verbose', true, @islogical);
    parse(p, varargin{:});
    params = p.Results;

    % Initialize timing
    totalTimer = tic;

    if params.Verbose
        fprintf('DWiM Volume Builder\n');
        fprintf('==================\n');
        fprintf('Processing DICOM series: %s\n', dicomPath);
        fprintf('Options: Orientation=%s, Resample=%s, Validate=%s\n', ...
                params.CorrectOrientation, params.Resample, params.Validate);
    end

    % Step 1: Discover and load DICOM files
    [dicomFiles, fileMetadata] = discoverAndLoadDicoms(dicomPath, params.Verbose);

    % Step 2: Sort slices by position
    sortedMetadata = sortSlicesByPosition(fileMetadata, params.Verbose);

    % Step 3: Assemble initial volume
    [rawVolume, assemblyInfo] = assembleRawVolume(sortedMetadata, params.Verbose);

    % Step 4: Extract spacing information
    voxelSpacing = extractVoxelSpacing(sortedMetadata);

    % Step 5: Orientation correction (optional)
    if params.CorrectOrientation
        [volume, orientationInfo] = applyOrientationCorrection(rawVolume, sortedMetadata, ...
            params.TargetOrientation, params.Verbose);
    else
        volume = rawVolume;
        orientationInfo = struct('applied', false, 'originalOrientation', 'unknown', ...
                               'targetOrientation', params.TargetOrientation);
    end

    % Step 6: Resampling (optional)
    if params.Resample
        [volume, resamplingInfo] = applyResampling(volume, voxelSpacing, ...
            params.TargetSpacing, params.Verbose);
        finalSpacing = [resamplingInfo.targetSpacing, resamplingInfo.targetSpacing, resamplingInfo.targetSpacing];
    else
        resamplingInfo = struct('applied', false, 'originalSpacing', voxelSpacing, ...
                              'targetSpacing', voxelSpacing);
        finalSpacing = voxelSpacing;
    end

    % Step 7: Validation (optional)
    if params.Validate
        validationInfo = validateFinalVolume(volume, finalSpacing, params.Verbose);
    else
        validationInfo = struct('performed', false);
    end

    % Generate comprehensive metadata
    metadata = generateBuildMetadata(dicomPath, params, dicomFiles, sortedMetadata, ...
                                   assemblyInfo, orientationInfo, resamplingInfo, ...
                                   validationInfo, toc(totalTimer));

    spacing = finalSpacing;

    if params.Verbose
        fprintf('Volume building completed: [%d %d %d] at [%.2f %.2f %.2f] mm\n', ...
                size(volume), spacing);
        fprintf('Total processing time: %.2f seconds\n', metadata.totalTime);
        fprintf('==================\n');
    end
end

function [dicomFiles, fileMetadata] = discoverAndLoadDicoms(dicomPath, verbose)
%DISCOVERANDLOADDICOMS Find and load DICOM file metadata

    if ~isfolder(dicomPath)
        error('dwim:buildVolumeFromSeries:InvalidPath', 'Directory does not exist: %s', dicomPath);
    end

    if verbose
        fprintf('Discovering DICOM files...\n');
    end

    % Find DICOM files
    dicomFiles = findDicomFiles(dicomPath);

    if isempty(dicomFiles)
        error('dwim:buildVolumeFromSeries:NoFiles', 'No DICOM files found in %s', dicomPath);
    end

    if verbose
        fprintf('Found %d potential DICOM files\n', length(dicomFiles));
    end

    % Load metadata from all files
    fileMetadata = struct('filename', {}, 'info', {}, 'position', {}, 'orientation', {});
    validCount = 0;

    for i = 1:length(dicomFiles)
        try
            info = dicominfo(dicomFiles{i});

            % Extract position
            if isfield(info, 'ImagePositionPatient')
                position = info.ImagePositionPatient(3); % Z position
            elseif isfield(info, 'SliceLocation')
                position = info.SliceLocation;
            else
                position = i; % Fallback
            end

            % Extract orientation if available
            orientation = [];
            if isfield(info, 'ImageOrientationPatient')
                orientation = info.ImageOrientationPatient;
            end

            validCount = validCount + 1;
            fileMetadata(validCount).filename = dicomFiles{i};
            fileMetadata(validCount).info = info;
            fileMetadata(validCount).position = position;
            fileMetadata(validCount).orientation = orientation;

        catch ME
            if verbose
                fprintf('  Skipping invalid file: %s (%s)\n', dicomFiles{i}, ME.message);
            end
        end
    end

    if validCount == 0
        error('dwim:buildVolumeFromSeries:NoValidFiles', 'No valid DICOM files found');
    end

    if verbose
        fprintf('Successfully loaded metadata from %d DICOM files\n', validCount);
    end
end

function dicomFiles = findDicomFiles(dicomPath)
%FINDDICOMFILES Find all DICOM files in directory
    extensions = {'*.dcm', '*.dicom', '*.DCM', '*.DICOM'};
    dicomFiles = {};

    for i = 1:length(extensions)
        files = dir(fullfile(dicomPath, extensions{i}));
        for j = 1:length(files)
            dicomFiles{end+1} = fullfile(files(j).folder, files(j).name);
        end
    end

    % Check files without extension
    allFiles = dir(dicomPath);
    for i = 1:length(allFiles)
        if ~allFiles(i).isdir && isempty(strfind(allFiles(i).name, '.'))
            filepath = fullfile(allFiles(i).folder, allFiles(i).name);
            try
                dicominfo(filepath);
                dicomFiles{end+1} = filepath;
            catch
                % Not DICOM, skip
            end
        end
    end
end

function sortedMetadata = sortSlicesByPosition(fileMetadata, verbose)
%SORTSLICESBYPOSITION Sort slices by Z position

    if verbose
        fprintf('Sorting slices by position...\n');
    end

    positions = [fileMetadata.position];
    [~, sortIdx] = sort(positions);

    sortedMetadata = fileMetadata(sortIdx);

    if verbose
        zPositions = [sortedMetadata.position];
        fprintf('Slices sorted from %.2f to %.2f mm\n', zPositions(1), zPositions(end));
    end
end

function [volume, assemblyInfo] = assembleRawVolume(sortedMetadata, verbose)
%ASSEMBLERAWVOLUME Assemble the 3D volume from sorted slices with memory optimization

    numSlices = length(sortedMetadata);

    if verbose
        fprintf('Assembling volume from %d slices...\n', numSlices);
    end

    % Read first slice to get dimensions and data type
    firstSlice = dicomread(sortedMetadata(1).info);
    [rows, cols] = size(firstSlice);
    dataType = class(firstSlice);
    
    % Memory estimation
    bytesPerElement = getDataTypeSize(dataType);
    estimatedMB = (rows * cols * numSlices * bytesPerElement) / (1024^2);
    
    if verbose
        fprintf('Estimated memory: %.1f MB\n', estimatedMB);
    end
    
    if estimatedMB > 2000  % Warn if > 2 GB
        warning('dwim:buildVolumeFromSeries:LargeVolume', ...
                'Assembling very large volume (%.1f MB). Memory issues may occur.', ...
                estimatedMB);
    end

    % Pre-allocate volume for memory efficiency
    volume = zeros(rows, cols, numSlices, dataType);

    % Read all slices
    for i = 1:numSlices
        slice = dicomread(sortedMetadata(i).info);

        % Basic validation
        if ~isequal(size(slice), [rows, cols])
            slice = imresize(slice, [rows, cols]);
        end

        volume(:, :, i) = slice;
    end

    assemblyInfo = struct('numSlices', numSlices, 'dimensions', [rows, cols, numSlices], ...
                         'dataType', class(volume));
end

function voxelSpacing = extractVoxelSpacing(sortedMetadata)
%EXTRACTVOXELSPACING Extract voxel spacing from DICOM metadata

    firstInfo = sortedMetadata(1).info;

    % Pixel spacing (X, Y)
    if isfield(firstInfo, 'PixelSpacing')
        pixelSpacing = firstInfo.PixelSpacing;
        xSpacing = pixelSpacing(1);
        ySpacing = pixelSpacing(2);
    else
        xSpacing = 1.0;
        ySpacing = 1.0;
    end

    % Slice thickness (Z)
    if length(sortedMetadata) > 1
        positions = [sortedMetadata.position];
        zSpacing = abs(positions(2) - positions(1));
    else
        zSpacing = 1.0;
    end

    voxelSpacing = [xSpacing, ySpacing, zSpacing];
end

function [correctedVolume, orientationInfo] = applyOrientationCorrection(volume, sortedMetadata, targetOrientation, verbose)
%APPLYORIENTATIONCORRECTION Apply orientation correction to volume

    if verbose
        fprintf('Applying orientation correction...\n');
    end

    % Use first slice metadata for orientation
    dicomInfo = sortedMetadata(1).info;

    % Apply correction
    [correctedVolume, transformMatrix] = dwim.preprocess3d.correctOrientation(volume, dicomInfo, ...
        'TargetOrientation', targetOrientation, 'Verbose', false);

    orientationInfo = struct('applied', true, 'transformMatrix', transformMatrix, ...
                           'targetOrientation', targetOrientation);
end

function [resampledVolume, resamplingInfo] = applyResampling(volume, voxelSpacing, targetSpacing, verbose)
%APPLYRESAMPLING Apply isotropic resampling

    if verbose
        fprintf('Applying isotropic resampling...\n');
    end

    % Resample volume
    [resampledVolume, resampleMetadata] = dwim.preprocess3d.resampleVolume(volume, ...
        'VoxelSpacing', voxelSpacing, 'TargetSpacing', targetSpacing, 'Verbose', false);

    resamplingInfo = struct('applied', true, 'originalSpacing', voxelSpacing, ...
                          'targetSpacing', resampleMetadata.targetSpacing, ...
                          'scaleFactor', resampleMetadata.scaleFactor, ...
                          'method', resampleMetadata.method);
end

function validationInfo = validateFinalVolume(volume, spacing, verbose)
%VALIDATEFINALVOLUME Run final validation checks

    if verbose
        fprintf('Running final validation...\n');
    end

    [isValid, validationResults] = dwim.preprocess3d.validateVolumeForML(volume, 'Verbose', false);

    validationInfo = struct('performed', true, 'isValid', isValid, ...
                          'results', validationResults);
end

function metadata = generateBuildMetadata(dicomPath, params, dicomFiles, sortedMetadata, ...
                                       assemblyInfo, orientationInfo, resamplingInfo, ...
                                       validationInfo, totalTime)
%GENERATEBUILDMETADATA Create comprehensive metadata

    metadata = struct();
    metadata.sourcePath = dicomPath;
    metadata.parameters = params;
    metadata.numFiles = length(dicomFiles);
    metadata.volumeInfo = assemblyInfo;
    metadata.orientationCorrection = orientationInfo;
    metadata.resampling = resamplingInfo;
    metadata.validation = validationInfo;
    metadata.totalTime = totalTime;

    % Extract patient/study info from first file
    if ~isempty(sortedMetadata)
        firstInfo = sortedMetadata(1).info;
        if isfield(firstInfo, 'PatientName')
            metadata.patientName = firstInfo.PatientName;
        end
        if isfield(firstInfo, 'StudyDescription')
            metadata.studyDescription = firstInfo.StudyDescription;
        end
        if isfield(firstInfo, 'Modality')
            metadata.modality = firstInfo.Modality;
        end
    end
end
function bytes = getDataTypeSize(dataType)
%GETDATATYPESIZE Get size in bytes for MATLAB data type
    switch dataType
        case {'int8', 'uint8'}
            bytes = 1;
        case {'int16', 'uint16'}
            bytes = 2;
        case {'int32', 'uint32', 'single'}
            bytes = 4;
        case {'int64', 'uint64', 'double'}
            bytes = 8;
        otherwise
            bytes = 8;  % Conservative fallback
    end
end
