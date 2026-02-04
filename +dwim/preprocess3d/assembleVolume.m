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
    addParameter(p, 'Verbose', true, @islogical);
    parse(p, varargin{:});
    params = p.Results;
    
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
        validateSliceSpacing(sortedInfo, params.Verbose);
    end
    
    % Assemble volume
    [volume, assemblyInfo] = assembleVolumeData(sortedInfo, params);
    
    % Generate metadata
    metadata = generateAssemblyMetadata(sortedInfo, assemblyInfo, params);
    
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
    
    % Common DICOM file extensions
    extensions = {'*.dcm', '*.dicom', '*.DCM', '*.DICOM'};
    dicomFiles = {};
    
    for i = 1:length(extensions)
        files = dir(fullfile(dicomPath, extensions{i}));
        for j = 1:length(files)
            dicomFiles{end+1} = fullfile(files(j).folder, files(j).name);
        end
    end
    
    % Also check files without extension (common in some systems)
    allFiles = dir(dicomPath);
    for i = 1:length(allFiles)
        [~, ~, ext] = fileparts(allFiles(i).name);
        if ~allFiles(i).isdir && isempty(ext)
            filepath = fullfile(allFiles(i).folder, allFiles(i).name);
            try
                dicominfo(filepath);  % Test if it's a valid DICOM
                dicomFiles{end+1} = filepath;
            catch
                % Not a DICOM file, skip
            end
        end
    end
end

function fileInfo = readAllMetadata(dicomFiles, verbose)
%READALLMETADATA Read metadata from all DICOM files
    numFiles = length(dicomFiles);
    fileInfoCell = cell(1, numFiles);
    
    if verbose
        fprintf('Reading metadata from %d files...\n', numFiles);
    end
    
    for i = 1:numFiles
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
            instanceNumber = i;  % Default fallback
            if isfield(info, 'InstanceNumber')
                instanceNumber = info.InstanceNumber;
            end
            
            fileInfoCell{i} = struct('filename', dicomFiles{i}, 'info', info, 'sliceLocation', sliceLocation, 'instanceNumber', instanceNumber);
            
        catch ME
            if verbose
                fprintf('Warning: Skipping invalid DICOM file: %s\n', dicomFiles{i});
            end
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
            [~, sortIdx] = sort([fileInfo.sliceLocation]);
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

function validateSliceSpacing(sortedInfo, verbose)
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
    if std(spacings) > 0.1 * abs(mean(spacings))
        warning('dwim:assembleVolume:InconsistentSpacing', ...
                'Inconsistent slice spacing detected (std=%.3f)', std(spacings));
    end
    
    % Check for missing slices (gaps larger than 2x mean spacing)
    meanSpacing = mean(spacings);
    largeGaps = find(abs(spacings) > 2 * abs(meanSpacing));
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
    
    % Read all slices
    for i = 1:numSlices
        try
            slice = dicomread(sortedInfo(i).info);
            
            % Validate slice dimensions
            if ~isequal(size(slice), [rows, cols])
                warning('dwim:assembleVolume:DimensionMismatch', ...
                        'Slice %d has different dimensions, resizing', i);
                slice = imresize(slice, [rows, cols]);
            end
            
            volume(:, :, i) = slice;
            
        catch ME
            warning('dwim:assembleVolume:SliceReadError', ...
                    'Error reading slice %d: %s', i, ME.message);
            % Leave as zeros
        end
    end
    
    assemblyInfo.numSlices = numSlices;
    assemblyInfo.dimensions = [rows, cols, numSlices];
    assemblyInfo.dataType = class(volume);
end

function metadata = generateAssemblyMetadata(sortedInfo, assemblyInfo, params)
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
        if sliceThickness < 0.01 || sliceThickness > 50
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