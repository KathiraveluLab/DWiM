function [isValid, report] = validateVolumeForML(volume, varargin)
%VALIDATEVOLUMEFORML Validate 3D medical volume for ML workflows
%
%   [isValid, report] = dwim.preprocess3d.validateVolumeForML(volume)
%       Validates if a 3D medical volume is suitable for ML preprocessing
%
%   [isValid, report] = dwim.preprocess3d.validateVolumeForML(volume, 'MinSlices', 10)
%       Validates with custom minimum slice requirements
%
%   Inputs:
%       volume - 3D numeric array representing medical volume
%
%   Name-Value Arguments:
%       MinSlices - Minimum number of slices required (default: 10)
%       MaxSlices - Maximum number of slices allowed (default: 1000)
%       MinSize - Minimum in-plane dimension (default: 32)
%       MaxSize - Maximum in-plane dimension (default: 2048)
%       AllowNaN - Allow NaN values (default: false)
%       AllowInf - Allow Inf values (default: false)
%       Verbose - Display validation details (default: true)
%
%   Outputs:
%       isValid - Boolean indicating if volume passes all checks
%       report - Structure with detailed validation results
%
%   Example:
%       [valid, report] = dwim.preprocess3d.validateVolumeForML(volume);
%       if ~valid
%           fprintf('Validation failed: %s\n', report.failureReason);
%       end

    arguments
        volume {mustBeNumeric}
        varargin
    end
    
    % Parse arguments
    p = inputParser;
    addParameter(p, 'MinSlices', 10, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'MaxSlices', 1000, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'MinSize', 32, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'MaxSize', 2048, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'AllowNaN', false, @islogical);
    addParameter(p, 'AllowInf', false, @islogical);
    addParameter(p, 'Verbose', true, @islogical);
    parse(p, varargin{:});
    params = p.Results;
    
    % Initialize report
    report = struct();
    report.timestamp = datetime('now');
    report.volumeSize = size(volume);
    report.dataType = class(volume);
    report.checks = struct();
    report.passed = true;
    report.failureReason = '';
    
    if params.Verbose
        fprintf('DWiM Volume Validation\n');
        fprintf('======================\n');
        fprintf('Volume size: [%d %d %d]\n', size(volume));
        fprintf('Data type: %s\n', class(volume));
    end
    
    % Check 1: Dimensionality
    if params.Verbose
        fprintf('Checking dimensionality... ');
    end
    
    if ndims(volume) ~= 3
        report.checks.dimensionality.passed = false;
        report.checks.dimensionality.message = sprintf('Expected 3D volume, got %dD', ndims(volume));
        report.passed = false;
        report.failureReason = 'Invalid dimensionality';
        if params.Verbose
            fprintf('FAILED (%s)\n', report.checks.dimensionality.message);
        end
        isValid = false;
        return;
    end
    
    report.checks.dimensionality.passed = true;
    if params.Verbose
        fprintf('PASSED\n');
    end
    
    % Check 2: Size constraints
    if params.Verbose
        fprintf('Checking size constraints... ');
    end
    
    [rows, cols, slices] = size(volume);
    
    sizeValid = true;
    sizeMessages = {};
    
    if slices < params.MinSlices
        sizeValid = false;
        sizeMessages{end+1} = sprintf('Too few slices (%d < %d)', slices, params.MinSlices);
    end
    
    if slices > params.MaxSlices
        sizeValid = false;
        sizeMessages{end+1} = sprintf('Too many slices (%d > %d)', slices, params.MaxSlices);
    end
    
    if rows < params.MinSize || cols < params.MinSize
        sizeValid = false;
        sizeMessages{end+1} = sprintf('In-plane size too small (%dx%d, min %d)', ...
                                       rows, cols, params.MinSize);
    end
    
    if rows > params.MaxSize || cols > params.MaxSize
        sizeValid = false;
        sizeMessages{end+1} = sprintf('In-plane size too large (%dx%d, max %d)', ...
                                       rows, cols, params.MaxSize);
    end
    
    report.checks.sizeConstraints.passed = sizeValid;
    report.checks.sizeConstraints.messages = sizeMessages;
    
    if ~sizeValid
        report.passed = false;
        report.failureReason = strjoin(sizeMessages, '; ');
        if params.Verbose
            fprintf('FAILED (%s)\n', report.failureReason);
        end
    else
        if params.Verbose
            fprintf('PASSED\n');
        end
    end
    
    % Check 3: Data quality (NaN/Inf)
    if params.Verbose
        fprintf('Checking data quality... ');
    end
    
    hasNaN = any(isnan(volume(:)));
    hasInf = any(isinf(volume(:)));
    
    dataQualityValid = true;
    dataQualityMessages = {};
    
    if hasNaN && ~params.AllowNaN
        dataQualityValid = false;
        nanCount = sum(isnan(volume(:)));
        dataQualityMessages{end+1} = sprintf('Contains %d NaN values', nanCount);
    end
    
    if hasInf && ~params.AllowInf
        dataQualityValid = false;
        infCount = sum(isinf(volume(:)));
        dataQualityMessages{end+1} = sprintf('Contains %d Inf values', infCount);
    end
    
    report.checks.dataQuality.passed = dataQualityValid;
    report.checks.dataQuality.hasNaN = hasNaN;
    report.checks.dataQuality.hasInf = hasInf;
    report.checks.dataQuality.messages = dataQualityMessages;
    
    if ~dataQualityValid
        report.passed = false;
        if isempty(report.failureReason)
            report.failureReason = strjoin(dataQualityMessages, '; ');
        else
            report.failureReason = [report.failureReason '; ' strjoin(dataQualityMessages, '; ')];
        end
        if params.Verbose
            fprintf('FAILED (%s)\n', strjoin(dataQualityMessages, '; '));
        end
    else
        if params.Verbose
            fprintf('PASSED\n');
        end
    end
    
    % Check 4: Value range
    if params.Verbose
        fprintf('Checking value range... ');
    end
    
    minVal = min(volume(:));
    maxVal = max(volume(:));
    meanVal = mean(volume(:));
    stdVal = std(double(volume(:)));
    
    report.checks.valueRange.min = minVal;
    report.checks.valueRange.max = maxVal;
    report.checks.valueRange.mean = meanVal;
    report.checks.valueRange.std = stdVal;
    report.checks.valueRange.passed = true;
    
    if params.Verbose
        fprintf('PASSED (range: [%.2f, %.2f], mean: %.2f)\n', minVal, maxVal, meanVal);
    end
    
    % Check 5: Empty slices
    if params.Verbose
        fprintf('Checking for empty slices... ');
    end
    
    emptySlices = [];
    for i = 1:slices
        slice = volume(:, :, i);
        if all(slice(:) == 0) || all(isnan(slice(:)))
            emptySlices(end+1) = i;
        end
    end
    
    emptySlicesValid = isempty(emptySlices);
    report.checks.emptySlices.passed = emptySlicesValid;
    report.checks.emptySlices.count = length(emptySlices);
    report.checks.emptySlices.indices = emptySlices;
    
    if ~emptySlicesValid
        if params.Verbose
            fprintf('WARNING (found %d empty slices)\n', length(emptySlices));
        end
        % This is a warning, not a failure
    else
        if params.Verbose
            fprintf('PASSED\n');
        end
    end
    
    % Final validation result
    isValid = report.passed;
    
    if params.Verbose
        fprintf('======================\n');
        if isValid
            fprintf('✓ Volume validation PASSED\n');
        else
            fprintf('✗ Volume validation FAILED: %s\n', report.failureReason);
        end
    end
end
