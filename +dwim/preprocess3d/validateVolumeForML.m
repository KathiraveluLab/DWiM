function [isValid, info] = validateVolumeForML(volume, varargin)
%VALIDATEVOLUMEFORML Validate 3D medical volume for ML workflows
%
%   [isValid, info] = dwim.preprocess3d.validateVolumeForML(volume)
%       Validates if a 3D medical volume is suitable for ML preprocessing
%
%   [isValid, info] = dwim.preprocess3d.validateVolumeForML(volume, 'MinSlices', 10)
%       Validates with custom minimum slice requirements
%
%   Inputs:
%       volume - 3D numeric array representing medical volume
%
%   Name-Value Arguments:
%       MinSize - Minimum required dimensions [rows, cols, slices] (default: [64, 64, 10])
%       MaxSize - Maximum allowed dimensions [rows, cols, slices] (default: [1024, 1024, 1000])
%       MinSlices - Minimum number of slices required (default: 5)
%       MaxSlices - Maximum number of slices allowed (default: 2000)
%       CheckIsotropic - Check if voxel spacing is isotropic (default: true)
%       MemoryLimitGB - Maximum memory usage in GB (default: 8)
%
%   Outputs:
%       isValid - Logical indicating if volume passes validation
%       info    - Structure with validation details and recommendations
%
%   Example:
%       [valid, details] = dwim.preprocess3d.validateVolumeForML(ctVolume);
%       if ~valid
%           fprintf('Issues: %s\n', strjoin(details.issues, '; '));
%       end

    arguments
        volume {mustBeNumeric}
    end

    arguments (Repeating)
        varargin
    end

    % Parse optional arguments
    p = inputParser;
    addParameter(p, 'MinSize', [64, 64, 5], @(x) isnumeric(x) && length(x) == 3);
    addParameter(p, 'MaxSize', [1024, 1024, 1000], @(x) isnumeric(x) && length(x) == 3);
    addParameter(p, 'MinSlices', 5, @isnumeric);
    addParameter(p, 'MaxSlices', 2000, @isnumeric);
    addParameter(p, 'CheckIsotropic', true, @islogical);
    addParameter(p, 'MemoryLimitGB', 8, @isnumeric);
    parse(p, varargin{:});

    params = p.Results;

    % Initialize validation results
    isValid = true;
    issues = {};
    warnings = {};
    recommendations = {};

    % Get volume dimensions
    [rows, cols, slices] = size(volume);

    % Check 1: Volume dimensions
    if rows < params.MinSize(1) || cols < params.MinSize(2) || slices < params.MinSize(3)
        isValid = false;
        issues{end+1} = sprintf('Volume too small (%dx%dx%d), minimum required: %dx%dx%d', ...
            rows, cols, slices, params.MinSize(1), params.MinSize(2), params.MinSize(3));
        recommendations{end+1} = 'Consider resampling or using different volume';
    end

    if rows > params.MaxSize(1) || cols > params.MaxSize(2) || slices > params.MaxSize(3)
        warnings{end+1} = sprintf('Volume very large (%dx%dx%d), may need downsampling', rows, cols, slices);
        recommendations{end+1} = 'Consider downsampling for memory efficiency';
    end

    % Check 2: Slice count
    if slices < params.MinSlices
        isValid = false;
        issues{end+1} = sprintf('Insufficient slices (%d), minimum required: %d', slices, params.MinSlices);
        recommendations{end+1} = 'Volume may not provide enough context for 3D models';
    end

    if slices > params.MaxSlices
        warnings{end+1} = sprintf('Very thick volume (%d slices), may be memory intensive', slices);
        recommendations{end+1} = 'Consider processing in chunks or subsampling';
    end

    % Check 3: Data type and range
    dataType = class(volume);
    if ~ismember(dataType, {'double', 'single', 'int16', 'uint16', 'int32', 'uint32'})
        warnings{end+1} = sprintf('Unusual data type: %s', dataType);
        recommendations{end+1} = 'Convert to float or int16 for ML processing';
    end

    % Check 4: Value range (typical for medical imaging)
    minVal = double(min(volume(:)));
    maxVal = double(max(volume(:)));

    if minVal >= 0 && maxVal <= 255
        warnings{end+1} = 'Values in [0,255] range - may be pre-windowed or normalized';
        recommendations{end+1} = 'Verify if this is raw data or pre-processed';
    elseif minVal < -2000 || maxVal > 4000
        warnings{end+1} = sprintf('Unusual HU range: [%.1f, %.1f]', minVal, maxVal);
        recommendations{end+1} = 'Check if values are in Hounsfield Units or properly scaled';
    end

    % Check 5: Volume content and quality
    volumeVariance = var(double(volume(:)));
    if volumeVariance < 1
        isValid = false;
        issues{end+1} = 'Volume has very low variance - may be blank or corrupted';
        recommendations{end+1} = 'Check data integrity and acquisition parameters';
    end

    % Check 6: Slice consistency (variance across slices)
    sliceMeans = squeeze(mean(mean(volume, 1), 2));
    sliceVariance = var(sliceMeans);
    if sliceVariance < 0.1
        warnings{end+1} = 'Very uniform slice intensities - may indicate processing artifacts';
        recommendations{end+1} = 'Check for preprocessing that may have reduced inter-slice variation';
    end

    % Check 7: Memory requirements
    bytesPerElement = getBytesPerElement(dataType);
    totalBytes = rows * cols * slices * bytesPerElement;
    totalGB = totalBytes / (1024^3);

    if totalGB > params.MemoryLimitGB
        warnings{end+1} = sprintf('High memory usage: %.2f GB (limit: %.1f GB)', totalGB, params.MemoryLimitGB);
        recommendations{end+1} = 'Consider downsampling or processing in smaller chunks';
    end

    % Check 8: Aspect ratio and anisotropy (if voxel spacing info available)
    % This would require DICOM metadata, but we can check basic aspect ratios
    aspectRatioXY = rows / cols;
    aspectRatioXZ = rows / slices;
    aspectRatioYZ = cols / slices;

    if aspectRatioXY > 5 || aspectRatioXY < 0.2
        warnings{end+1} = sprintf('Extreme XY aspect ratio: %.2f', aspectRatioXY);
        recommendations{end+1} = 'Consider resampling for more isotropic voxels';
    end

    if aspectRatioXZ > 10 || aspectRatioXZ < 0.1
        warnings{end+1} = sprintf('Extreme XZ aspect ratio: %.2f', aspectRatioXZ);
        recommendations{end+1} = 'Volume may need slice interpolation or resampling';
    end

    % Check 9: Data integrity (NaN/Inf values)
    numNaN = sum(isnan(volume(:)));
    numInf = sum(isinf(volume(:)));

    if numNaN > 0
        isValid = false;
        issues{end+1} = sprintf('Volume contains %d NaN values', numNaN);
        recommendations{end+1} = 'Replace or interpolate NaN values';
    end

    if numInf > 0
        isValid = false;
        issues{end+1} = sprintf('Volume contains %d Inf values', numInf);
        recommendations{end+1} = 'Check for division by zero or invalid operations';
    end

    % Compile results
    info = struct();
    info.dimensions = [rows, cols, slices];
    info.dataType = dataType;
    info.valueRange = [minVal, maxVal];
    info.variance = volumeVariance;
    info.sliceVariance = sliceVariance;
    info.memoryUsageGB = totalGB;
    info.aspectRatios = [aspectRatioXY, aspectRatioXZ, aspectRatioYZ];
    info.numNaN = numNaN;
    info.numInf = numInf;
    info.issues = issues;
    info.warnings = warnings;
    info.recommendations = recommendations;
    info.isValid = isValid;

    % Overall assessment
    if isValid && isempty(warnings)
        info.assessment = 'Volume is ready for ML workflows';
    elseif isValid
        info.assessment = 'Volume is valid but has minor concerns';
    else
        info.assessment = 'Volume has issues that need to be addressed';
    end
end

function bytes = getBytesPerElement(dataType)
%GETBYTESPERELEMENT Get bytes per element for different data types
    switch dataType
        case 'double'
            bytes = 8;
        case 'single'
            bytes = 4;
        case {'int32', 'uint32'}
            bytes = 4;
        case {'int16', 'uint16'}
            bytes = 2;
        case {'int8', 'uint8'}
            bytes = 1;
        otherwise
            bytes = 8; % Default assumption
    end
end