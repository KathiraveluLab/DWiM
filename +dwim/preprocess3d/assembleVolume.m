function [volume, metadata] = assembleVolume(dicomPath, varargin)
%ASSEMBLEVOLUME Assemble 3D volume from DICOM series
%
%   [volume, metadata] = assembleVolume(dicomPath)
%       Assembles 3D volume from DICOM files in specified directory
%
%   [volume, metadata] = assembleVolume(dicomPath, 'SortBy', method)
%       Uses specified sorting method ('SliceLocation', 'InstanceNumber')
%
%   Inputs:
%       dicomPath - Path to directory containing DICOM files
%
%   Name-Value Arguments:
%       SortBy - Slice sorting method (default: 'SliceLocation')
%       ValidateSpacing - Check slice spacing consistency (default: true)
%       FillGaps - Interpolate missing slices (default: false)
%       Verbose - Display progress information (default: true)
%
%   Outputs:
%       volume - Assembled 3D volume
%       metadata - Structure with assembly information
%
%   Example:
%       [volume, info] = dwim.preprocess3d.assembleVolume('path/to/dicom/');
%       fprintf('Assembled volume: [%d %d %d]\n', size(volume));

    arguments
        dicomPath (1,1) string
        varargin
    end
    
    % Parse arguments
    p = inputParser;
    addParameter(p, 'SortBy', 'SliceLocation', @(x) ismember(x, {'SliceLocation', 'InstanceNumber'}));
    addParameter(p, 'ValidateSpacing', true, @islogical);
    addParameter(p, 'FillGaps', false, @islogical);
    addParameter(p, 'AllowResizing', true, @islogical);  % Whether to auto-resize mismatched slices
    addParameter(p, 'Verbose', true, @islogical);
    parse(p, varargin{:});
    params = p.Results;
    
    % Define constants for thresholds
    INCONSISTENT_SPACING_THRESHOLD = 0.1;      % 10% variation triggers warning
    MISSING_SLICE_GAP_FACTOR = 2;              % Gap > 2x mean indicates missing slice
    MIN_REALISTIC_THICKNESS = 0.01;            % mm
    MAX_REALISTIC_THICKNESS = 50;              % mm
    
    if params.Verbose
        fprintf('DWiM Volume Assembly\n');
        fprintf('===================\n');
        fprintf('Scanning directory: %s\n', dicomPath);
    end
    
    % Find DICOM files
    dicomFiles = findDicomFiles(dicomPath);
    if isempty(dicomFiles)
        error('dwim:assembleVolume:NoFiles', 'No DICOM files found in %s', dicomPath);
    end
    
    if params.Verbose
        fprintf('Found %d DICOM files\n', length(dicomFiles));
    end
    
    % Read metadata from all files
    fileInfo = readAllMetadata(dicomFiles, params.Verbose);
    
    % Sort slices
    sortedInfo = sortSlices(fileInfo, params.SortBy, params.Verbose);
    
    % Validate spacing if requested
    if params.ValidateSpacing
        validateSliceSpacing(sortedInfo, params.Verbose, INCONSISTENT_SPACING_THRESHOLD, MISSING_SLICE_GAP_FACTOR);
    end
    
    % Assemble volume
    [volume, assemblyInfo] = assembleVolumeData(sortedInfo, params);
    
    % Generate metadata
    metadata = generateAssemblyMetadata(sortedInfo, assemblyInfo, params, MIN_REALISTIC_THICKNESS, MAX_REALISTIC_THICKNESS);
    
    if params.Verbose
        fprintf('Volume assembly completed: [%d %d %d]\n', size(volume));
        fprintf('===================\n');
    end
end

function dicomFiles = findDicomFiles(dicomPath)
%FINDDICOMFILES Find all DICOM files in directory
    if ~isfolder(dicomPath)
        error('dwim:assembleVolume:InvalidPath', 'Directory does not exist: %s', dicomPath);
    end
    
    % Common DICOM file extensions - collect all file structs first
    extensions = {'*.dcm', '*.dicom', '*.DCM', '*.DICOM'};
    allFilesStructs = cell(1, length(extensions));
    for i = 1:length(extensions)
        allFilesStructs{i} = dir(fullfile(dicomPath, extensions{i}));
    end
    allFilesStruct = vertcat(allFilesStructs{:});
    
    % Construct paths vectorized
    if ~isempty(allFilesStruct)
        dicomFiles = fullfile({allFilesStruct.folder}, {allFilesStruct.name})';
    else
        dicomFiles = {};
    end
    
    % Also check files without extension (common in some systems)
    allFiles = dir(dicomPath);
    extlessPaths = cell(length(allFiles), 1);
    numExtless = 0;
    for i = 1:length(allFiles)
        [~, ~, ext] = fileparts(allFiles(i).name);
        if ~allFiles(i).isdir && isempty(ext)
            filepath = fullfile(allFiles(i).folder, allFiles(i).name);
            if isdicom(filepath)  % Fast header check for DICOM
                numExtless = numExtless + 1;
                extlessPaths{numExtless} = filepath;
            end
        end
    end
    if numExtless > 0
        dicomFiles = [dicomFiles; extlessPaths(1:numExtless)];
    end
end

function fileInfo = readAllMetadata(dicomFiles, verbose)
%READALLMETADATA Read metadata from all DICOM files
    numFiles = length(dicomFiles);
    fileInfoCell = cell(1, numFiles);
    
    if verbose
        fprintf('Reading metadata from %d files...\n', numFiles);
    end
    
    % Parallelize metadata reading for performance
    parfor i = 1:numFiles
        try
            info = dicominfo(dicomFiles{i});
            
            % Extract slice location
            sliceLocation = 0;
            if isfield(info, 'SliceLocation')
                sliceLocation = info.SliceLocation;
            elseif isfield(info, 'ImagePositionPatient')
                % Use Z coordinate from ImagePositionPatient
                sliceLocation = info.ImagePositionPatient(3);
            end
            
            % Extract instance number
            if isfield(info, 'InstanceNumber')
                instanceNumber = info.InstanceNumber;
            else
                instanceNumber = i;  % Default fallback - may not reflect true order
            end
            
            fileInfoCell{i} = struct('filename', dicomFiles{i}, 'info', info, 'sliceLocation', sliceLocation, 'instanceNumber', instanceNumber);
            
        catch ME
            % fileInfoCell{i} will remain empty
        end
    end
    
    % Filter out failed reads and convert to struct array
    fileInfo = [fileInfoCell{~cellfun('isempty', fileInfoCell)}];
    validFiles = length(fileInfo);
    
    if verbose
        fprintf('Successfully read %d valid DICOM files\n', validFiles);
    end
    
    if validFiles == 0
        error('dwim:assembleVolume:NoValidFiles', 'No valid DICOM files found');
    end
end

function sortedInfo = sortSlices(fileInfo, sortBy, verbose)
%SORTSLICES Sort slices by specified method
    if verbose
        fprintf('Sorting slices by %s...\n', sortBy);
    end
    
    switch sortBy
        case 'SliceLocation'
            locations = [fileInfo.sliceLocation];
            if numel(unique(locations)) == 1 && length(locations) > 1
                warning('dwim:assembleVolume:AmbiguousSort', ...
                        'All slice locations are identical. Sorting by SliceLocation may result in an incorrect volume order. Consider using ''InstanceNumber''.');
            end
            [~, sortIdx] = sort(locations);
        case 'InstanceNumber'
            [~, sortIdx] = sort([fileInfo.instanceNumber]);
        otherwise
            error('dwim:assembleVolume:InvalidSortMethod', 'Invalid sort method: %s', sortBy);
    end
    
    sortedInfo = fileInfo(sortIdx);
    
    if verbose
        fprintf('Slices sorted from %.2f to %.2f\n', ...
                sortedInfo(1).sliceLocation, sortedInfo(end).sliceLocation);
    end
end

function validateSliceSpacing(sortedInfo, verbose, INCONSISTENT_SPACING_THRESHOLD, MISSING_SLICE_GAP_FACTOR)
%VALIDATESLICESPACING Check for consistent slice spacing
    if length(sortedInfo) < 2
        return;
    end
    
    locations = [sortedInfo.sliceLocation];
    spacings = diff(locations);
    
    if verbose
        fprintf('Slice spacing validation:\n');
        fprintf('  Mean spacing: %.3f mm\n', mean(spacings));
        fprintf('  Std spacing: %.3f mm\n', std(spacings));
    end
    
    % Check for large variations in spacing
    if std(spacings) > INCONSISTENT_SPACING_THRESHOLD * abs(mean(spacings))
        warning('dwim:assembleVolume:InconsistentSpacing', ...
                'Inconsistent slice spacing detected (std=%.3f)', std(spacings));
    end
    
    % Check for missing slices (gaps larger than threshold)
    meanSpacing = mean(spacings);
    largeGaps = find(abs(spacings) > MISSING_SLICE_GAP_FACTOR * abs(meanSpacing));
    if ~isempty(largeGaps)
        warning('dwim:assembleVolume:MissingSlices', ...
                'Potential missing slices detected at %d locations', length(largeGaps));
    end
end

function [volume, assemblyInfo] = assembleVolumeData(sortedInfo, params)
%ASSEMBLEVOLUMEDATA Assemble the actual volume data
    numSlices = length(sortedInfo);
    
    % Read first slice to get dimensions
    firstImage = dicomread(sortedInfo(1).info);
    [rows, cols] = size(firstImage);
    
    % Initialize volume
    volume = zeros(rows, cols, numSlices, class(firstImage));
    
    if params.Verbose
        fprintf('Assembling volume: [%d %d %d]\n', rows, cols, numSlices);
    end
    
    % Read all slices - parallelize for performance
    sliceData = cell(1, numSlices);
    resizeFlags = false(1, numSlices);
    errorFlags = false(1, numSlices);
    
    parfor i = 1:numSlices
        try
            slice = dicomread(sortedInfo(i).info);
            
            % Check slice dimensions
            if ~isequal(size(slice), [rows, cols])
                resizeFlags(i) = true;
                if params.AllowResizing
                    slice = imresize(slice, [rows, cols]);
                else
                    errorFlags(i) = true;
                    slice = [];
                end
            end
            
            sliceData{i} = slice;
            
        catch ME
            errorFlags(i) = true;
            sliceData{i} = [];
        end
    end
    
    % Assemble volume from slices and handle errors/warnings
    for i = 1:numSlices
        if errorFlags(i)
            if ~isempty(sliceData{i})
                % Dimension mismatch with AllowResizing=false
                error('dwim:assembleVolume:DimensionMismatch', ...
                      'Slice %d has different dimensions. Set ''AllowResizing'' to true to handle this automatically.', i);
            else
                % Read error
                warning('dwim:assembleVolume:SliceReadError', ...
                        'Error reading slice %d', i);
            end
        elseif resizeFlags(i)
            warning('dwim:assembleVolume:DimensionMismatch', ...
                    'Slice %d has different dimensions, resizing', i);
        end
        
        if ~isempty(sliceData{i})
            volume(:, :, i) = sliceData{i};
        end
    end
    
    assemblyInfo.numSlices = numSlices;
    assemblyInfo.dimensions = [rows, cols, numSlices];
    assemblyInfo.dataType = class(volume);
end

function metadata = generateAssemblyMetadata(sortedInfo, assemblyInfo, params, MIN_REALISTIC_THICKNESS, MAX_REALISTIC_THICKNESS)
%GENERATEASSEMBLYMETADATA Create comprehensive assembly metadata
    metadata = struct();
    metadata.numFiles = length(sortedInfo);
    metadata.dimensions = assemblyInfo.dimensions;
    metadata.dataType = assemblyInfo.dataType;
    metadata.sortMethod = params.SortBy;
    
    % Extract voxel spacing
    firstInfo = sortedInfo(1).info;
    if isfield(firstInfo, 'PixelSpacing')
        pixelSpacing = firstInfo.PixelSpacing;
        metadata.pixelSpacing = [pixelSpacing(1), pixelSpacing(2)];
    else
        metadata.pixelSpacing = [1.0, 1.0];
    end
    
    % Calculate slice thickness with improved logic
    if length(sortedInfo) > 1
        locations = [sortedInfo.sliceLocation];
        spacings = diff(locations);
        
        % Use median for robustness against outliers
        sliceThickness = abs(median(spacings));
        
        % Fallback if median is zero or unrealistic
        if sliceThickness < MIN_REALISTIC_THICKNESS || sliceThickness > MAX_REALISTIC_THICKNESS
            sliceThickness = abs(mean(spacings(spacings ~= 0)));
            if isnan(sliceThickness) || sliceThickness < 0.01
                sliceThickness = 1.0;  % Default fallback
            end
        end
        
        metadata.sliceThickness = sliceThickness;
        metadata.voxelSpacing = [metadata.pixelSpacing(1), metadata.pixelSpacing(2), sliceThickness];
    else
        metadata.sliceThickness = 1.0;
        metadata.voxelSpacing = [metadata.pixelSpacing(1), metadata.pixelSpacing(2), 1.0];
    end
    
    % Patient and study information
    if isfield(firstInfo, 'PatientName')
        metadata.patientName = firstInfo.PatientName;
    end
    if isfield(firstInfo, 'StudyDescription')
        metadata.studyDescription = firstInfo.StudyDescription;
    end
    if isfield(firstInfo, 'Modality')
        metadata.modality = firstInfo.Modality;
    end
    
    metadata.assemblyParams = params;
end
