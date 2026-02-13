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
        varargin
    end
    
    p = inputParser;
    addParameter(p, 'CheckMetadata', true, @islogical);
    addParameter(p, 'CheckSpacing', true, @islogical);
    addParameter(p, 'Verbose', true, @islogical);
    parse(p, varargin{:});
    params = p.Results;
    
    result = struct();
    result.valid = true;
    result.errors = {};
    result.warnings = {};
    result.path = inputPath;
    
    if params.Verbose
        fprintf('DWiM Preprocessing Input Validation\n');
        fprintf('===================================\n');
    end
    
    % Guard 1: Empty folder check
    emptyCheck = checkEmptyFolder(inputPath, params.Verbose);
    if ~emptyCheck.passed
        result.valid = false;
        result.errors{end+1} = emptyCheck.error;
        return;
    end
    
    % Guard 2: Missing metadata check
    if params.CheckMetadata
        metadataCheck = checkMetadata(inputPath, params.Verbose);
        if ~metadataCheck.passed
            result.valid = false;
            result.errors = [result.errors, metadataCheck.errors];
        end
        result.warnings = [result.warnings, metadataCheck.warnings];
    end
    
    % Guard 3: Slice spacing consistency check
    if params.CheckSpacing
        spacingCheck = checkSliceSpacing(inputPath, params.Verbose);
        if ~spacingCheck.passed
            result.warnings = [result.warnings, spacingCheck.warnings];
        end
        result.spacingInfo = spacingCheck.info;
    end
    
    if params.Verbose
        fprintf('Validation: %s\n', ternary(result.valid, 'PASSED', 'FAILED'));
        fprintf('===================================\n');
    end
end

function result = checkEmptyFolder(inputPath, verbose)
%CHECKEMPTYFOLDER Guard against empty input folders
    
    result = struct('passed', true, 'error', struct());
    
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

function result = checkMetadata(inputPath, verbose)
%CHECKMETADATA Guard against missing critical DICOM metadata
    
    result = struct('passed', true, 'errors', {{}}, 'warnings', {{}});
    
    dicomFiles = [dir(fullfile(inputPath, '*.dcm')); ...
                  dir(fullfile(inputPath, '*.dicom'))];
    
    requiredFields = {'ImagePositionPatient', 'ImageOrientationPatient', 'PixelSpacing'};
    missingCount = 0;
    
    for i = 1:min(5, length(dicomFiles)) % Check first 5 files
        filePath = fullfile(dicomFiles(i).folder, dicomFiles(i).name);
        
        try
            info = dicominfo(filePath);
            
            for j = 1:length(requiredFields)
                field = requiredFields{j};
                if ~isfield(info, field)
                    missingCount = missingCount + 1;
                    result.warnings{end+1} = sprintf('Missing %s in %s', field, dicomFiles(i).name);
                end
            end
            
        catch ME
            result.errors{end+1} = struct(...
                'identifier', 'DWiM:Validation:MissingMetadata', ...
                'message', sprintf('Failed to read metadata from %s: %s', dicomFiles(i).name, ME.message));
            result.passed = false;
        end
    end
    
    if missingCount > 0 && verbose
        fprintf('WARNING: %d metadata fields missing across sampled files\n', missingCount);
    end
    
    if result.passed && verbose
        fprintf('Metadata validation: PASSED\n');
    end
end

function result = checkSliceSpacing(inputPath, verbose)
%CHECKSLICESPACING Check slice spacing consistency
    
    result = struct('passed', true, 'warnings', {{}}, 'info', struct());
    
    dicomFiles = [dir(fullfile(inputPath, '*.dcm')); ...
                  dir(fullfile(inputPath, '*.dicom'))];
    
    if length(dicomFiles) < 2
        result.warnings{end+1} = 'Insufficient slices for spacing check';
        return;
    end
    
    positions = zeros(length(dicomFiles), 3);
    
    for i = 1:length(dicomFiles)
        filePath = fullfile(dicomFiles(i).folder, dicomFiles(i).name);
        try
            info = dicominfo(filePath);
            if isfield(info, 'ImagePositionPatient')
                positions(i, :) = info.ImagePositionPatient';
            elseif isfield(info, 'SliceLocation')
                positions(i, 3) = info.SliceLocation;
            end
        catch
            continue;
        end
    end
    
    % Calculate slice spacings
    [~, sortIdx] = sort(positions(:, 3));
    sortedPositions = positions(sortIdx, :);
    spacings = diff(sortedPositions(:, 3));
    
    if ~isempty(spacings)
        result.info.meanSpacing = mean(abs(spacings));
        result.info.stdSpacing = std(spacings);
        result.info.minSpacing = min(abs(spacings));
        result.info.maxSpacing = max(abs(spacings));
        
        % Check consistency (std > 10% of mean)
        if result.info.stdSpacing > 0.1 * result.info.meanSpacing
            result.passed = false;
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

function result = ternary(condition, trueVal, falseVal)
    if condition
        result = trueVal;
    else
        result = falseVal;
    end
end