function result = validatePreprocessingInput(inputPath, varargin)
%VALIDATEPREPROCESSINGINPUT Validate input for ML preprocessing pipeline
%
%   result = validatePreprocessingInput(inputPath)
%       Validates DICOM directory or file for preprocessing
%
%   Name-Value Arguments:
%       CheckMetadata - Validate DICOM metadata presence (default: true)
%       CheckSpacing - Validate slice spacing consistency (default: true)
%       Verbose - Display validation messages (default: true)
%
%   Outputs:
%       result - Struct with validation results and error identifiers
%
%   Error Identifiers:
%       DWiM:Validation:EmptyFolder
%       DWiM:Validation:MissingMetadata
%       DWiM:Validation:InconsistentSpacing
%       DWiM:Validation:InvalidPath

    arguments
        inputPath (1,1) string
        options.CheckMetadata (1,1) logical = true
        options.CheckSpacing (1,1) logical = true
        options.Verbose (1,1) logical = true
    end
    
    result = struct('valid', true, 'errors', {{}}, 'warnings', {{}}, 'path', inputPath, 'spacingInfo', struct());
    
    if options.Verbose
        fprintf('DWiM Preprocessing Input Validation\n');
        fprintf('===================================\n');
    end
    
    % Guard 1: Empty folder check and get DICOM files
    [emptyCheck, dicomFiles] = checkEmptyFolder(inputPath, options.Verbose);
    if ~emptyCheck.passed
        result.valid = false;
        result.errors{end+1} = emptyCheck.error;
        return;
    end
    
    % Guard 2: Missing metadata check
    if options.CheckMetadata
        metadataCheck = checkMetadata(dicomFiles, options.Verbose);
        if ~metadataCheck.passed
            result.valid = false;
            result.errors = [result.errors, metadataCheck.errors];
        end
    end
    
    % Guard 3: Slice spacing consistency check
    if options.CheckSpacing
        spacingCheck = checkSliceSpacing(dicomFiles, options.Verbose);
        result.warnings = [result.warnings, spacingCheck.warnings];
        result.spacingInfo = spacingCheck.info;
    end
    
    if options.Verbose
        if result.valid
            fprintf('Validation: PASSED\n');
        else
            fprintf('Validation: FAILED\n');
        end
        fprintf('===================================\n');
    end
end

function [result, dicomFiles] = checkEmptyFolder(inputPath, verbose)
%CHECKEMPTYFOLDER Guard against empty input folders
    
    result = struct('passed', true, 'error', struct());
    dicomFiles = [];
    
    if ~exist(inputPath, 'dir')
        result.passed = false;
        result.error.identifier = 'DWiM:Validation:InvalidPath';
        result.error.message = sprintf('Path does not exist: %s', inputPath);
        if verbose
            fprintf('ERROR: %s\n', result.error.message);
        end
        return;
    end
    
    % Check for DICOM files
    dicomFiles = [dir(fullfile(inputPath, '*.dcm')); ...
                  dir(fullfile(inputPath, '*.dicom'))];
    
    if isempty(dicomFiles)
        result.passed = false;
        result.error.identifier = 'DWiM:Validation:EmptyFolder';
        result.error.message = sprintf('No DICOM files found in: %s', inputPath);
        if verbose
            fprintf('ERROR: %s\n', result.error.message);
        end
        return;
    end
    
    if verbose
        fprintf('Found %d DICOM files\n', length(dicomFiles));
    end
end

function result = checkMetadata(dicomFiles, verbose)
%CHECKMETADATA Guard against missing critical DICOM metadata
    
    result = struct('passed', true, 'errors', {{}});
    
    requiredFields = {'ImagePositionPatient', 'ImageOrientationPatient', 'PixelSpacing'};
    
    for i = 1:min(5, length(dicomFiles)) % Check first 5 files
        filePath = fullfile(dicomFiles(i).folder, dicomFiles(i).name);
        
        try
            info = dicominfo(filePath);
            
            for j = 1:length(requiredFields)
                field = requiredFields{j};
                if ~isfield(info, field)
                    err = struct(...
                        'identifier', 'DWiM:Validation:MissingMetadata', ...
                        'message', sprintf('Missing critical field ''%s'' in %s', field, dicomFiles(i).name));
                    result.errors{end+1} = err;
                end
            end
            
        catch ME
            result.errors{end+1} = struct(...
                'identifier', 'DWiM:Validation:MissingMetadata', ...
                'message', sprintf('Failed to read metadata from %s: %s', dicomFiles(i).name, ME.message));
        end
    end
    
    result.passed = isempty(result.errors);
    
    if result.passed && verbose
        fprintf('Metadata validation: PASSED\n');
    elseif ~result.passed && verbose
        fprintf('ERROR: Critical metadata fields missing or unreadable\n');
    end
end

function result = checkSliceSpacing(dicomFiles, verbose)
%CHECKSLICESPACING Check slice spacing consistency
    
    result = struct('passed', true, 'warnings', {{}}, 'info', struct());
    
    if length(dicomFiles) < 2
        result.warnings{end+1} = 'Insufficient slices for spacing check';
        return;
    end
    
    sliceDistances = zeros(length(dicomFiles), 1);
    isValid = false(length(dicomFiles), 1);
    sliceNormal = [];
    hasWarned = false;
    
    for i = 1:length(dicomFiles)
        filePath = fullfile(dicomFiles(i).folder, dicomFiles(i).name);
        try
            info = dicominfo(filePath);
            if isfield(info, 'ImagePositionPatient')
                if isempty(sliceNormal) && isfield(info, 'ImageOrientationPatient')
                    rowVec = info.ImageOrientationPatient(1:3)';
                    colVec = info.ImageOrientationPatient(4:6)';
                    sliceNormal = cross(rowVec, colVec);
                end
                
                if ~isempty(sliceNormal)
                    sliceDistances(i) = dot(info.ImagePositionPatient, sliceNormal);
                else
                    if ~hasWarned && verbose
                        fprintf('WARNING: ImageOrientationPatient not found. Using Z-coordinate for spacing. This may be inaccurate for non-axial series.\n');
                        hasWarned = true;
                    end
                    sliceDistances(i) = info.ImagePositionPatient(3);
                end
                isValid(i) = true;
            elseif isfield(info, 'SliceLocation')
                sliceDistances(i) = info.SliceLocation;
                isValid(i) = true;
            end
        catch ME
            if verbose
                fprintf('WARNING: Could not read metadata from %s. Skipping for spacing calculation. Error: %s\n', dicomFiles(i).name, ME.message);
            end
            continue;
        end
    end
    
    validSliceDistances = sliceDistances(isValid);
    
    if length(validSliceDistances) < 2
        result.warnings{end+1} = 'Insufficient valid slices for spacing check';
        return;
    end
    
    sortedDistances = sort(validSliceDistances);
    spacings = diff(sortedDistances);
    
    if ~isempty(spacings)
        result.info.meanSpacing = mean(abs(spacings));
        result.info.stdSpacing = std(spacings);
        result.info.minSpacing = min(abs(spacings));
        result.info.maxSpacing = max(abs(spacings));
        
        if result.info.stdSpacing > 0.1 * result.info.meanSpacing
            result.warnings{end+1} = sprintf(...
                'Inconsistent slice spacing detected (std=%.3f, mean=%.3f)', ...
                result.info.stdSpacing, result.info.meanSpacing);
        end
        
        if verbose
            fprintf('Slice spacing: mean=%.2fmm, std=%.3fmm, range=[%.2f-%.2f]mm\n', ...
                    result.info.meanSpacing, result.info.stdSpacing, ...
                    result.info.minSpacing, result.info.maxSpacing);
        end
    end
end

