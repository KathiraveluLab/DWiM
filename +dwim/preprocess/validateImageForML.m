function [isValid, report] = validateImageForML(image, varargin)
%VALIDATEIMAGEFORML Validate 2D image for machine learning workflows
%
%   [isValid, report] = validateImageForML(image)
%       Validates 2D image for ML readiness
%
%   [isValid, report] = validateImageForML(image, 'MinSize', N)
%       Validates with custom minimum dimension
%
%   Inputs:
%       image - 2D numeric array
%
%   Name-Value Arguments:
%       MinSize - Minimum dimension (default: 32)
%       MaxSize - Maximum dimension (default: 2048)
%       AllowNaN - Allow NaN values (default: false)
%       AllowInf - Allow Inf values (default: false)
%       RequireNormalized - Require values in [0,1] (default: false)
%       Verbose - Display validation details (default: true)
%
%   Outputs:
%       isValid - Boolean indicating if image passes all checks
%       report - Structure with detailed validation results
%
%   Example:
%       [valid, report] = dwim.preprocess.validateImageForML(image);
%       if ~valid
%           fprintf('Validation failed: %s\n', report.failureReason);
%       end

    arguments
        image {mustBeNumeric}
        varargin
    end
    
    % Parse arguments
    p = inputParser;
    addParameter(p, 'MinSize', 32, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'MaxSize', 2048, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'AllowNaN', false, @islogical);
    addParameter(p, 'AllowInf', false, @islogical);
    addParameter(p, 'RequireNormalized', false, @islogical);
    addParameter(p, 'Verbose', true, @islogical);
    parse(p, varargin{:});
    params = p.Results;
    
    % Initialize report
    report = struct();
    report.timestamp = datetime('now');
    report.imageSize = size(image);
    report.dataType = class(image);
    report.checks = struct();
    report.passed = true;
    report.failureReason = '';
    
    if params.Verbose
        fprintf('DWiM Image Validation\n');
        fprintf('=====================\n');
        fprintf('Image size: [%d %d]\n', size(image));
        fprintf('Data type: %s\n', class(image));
    end
    
    % Check 1: Dimensionality
    if params.Verbose
        fprintf('Checking dimensionality... ');
    end
    
    if ndims(image) ~= 2
        report.checks.dimensionality.passed = false;
        report.checks.dimensionality.message = sprintf('Expected 2D image, got %dD', ndims(image));
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
    
    [rows, cols] = size(image);
    
    sizeValid = true;
    sizeMessages = {};
    
    if rows < params.MinSize || cols < params.MinSize
        sizeValid = false;
        sizeMessages{end+1} = sprintf('Image too small (%dx%d, min %d)', ...
                                       rows, cols, params.MinSize);
    end
    
    if rows > params.MaxSize || cols > params.MaxSize
        sizeValid = false;
        sizeMessages{end+1} = sprintf('Image too large (%dx%d, max %d)', ...
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
    
    hasNaN = any(isnan(image(:)));
    hasInf = any(isinf(image(:)));
    
    dataQualityValid = true;
    dataQualityMessages = {};
    
    if hasNaN && ~params.AllowNaN
        dataQualityValid = false;
        nanCount = sum(isnan(image(:)));
        dataQualityMessages{end+1} = sprintf('Contains %d NaN values', nanCount);
    end
    
    if hasInf && ~params.AllowInf
        dataQualityValid = false;
        infCount = sum(isinf(image(:)));
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
    
    minVal = min(image(:));
    maxVal = max(image(:));
    meanVal = mean(image(:));
    stdVal = std(double(image(:)));
    
    report.checks.valueRange.min = minVal;
    report.checks.valueRange.max = maxVal;
    report.checks.valueRange.mean = meanVal;
    report.checks.valueRange.std = stdVal;
    report.checks.valueRange.passed = true;
    
    % Check normalization if required
    if params.RequireNormalized
        if minVal < 0 || maxVal > 1
            report.checks.valueRange.passed = false;
            report.passed = false;
            normalizeMsg = sprintf('Values not normalized (range: [%.2f, %.2f])', minVal, maxVal);
            if isempty(report.failureReason)
                report.failureReason = normalizeMsg;
            else
                report.failureReason = [report.failureReason '; ' normalizeMsg];
            end
            if params.Verbose
                fprintf('FAILED (%s)\n', normalizeMsg);
            end
        else
            if params.Verbose
                fprintf('PASSED (normalized range: [%.2f, %.2f])\n', minVal, maxVal);
            end
        end
    else
        if params.Verbose
            fprintf('PASSED (range: [%.2f, %.2f], mean: %.2f)\n', minVal, maxVal, meanVal);
        end
    end
    
    % Check 5: Empty image
    if params.Verbose
        fprintf('Checking for empty image... ');
    end
    
    isEmpty = all(image(:) == 0) || all(isnan(image(:)));
    
    report.checks.emptyImage.passed = ~isEmpty;
    
    if isEmpty
        report.passed = false;
        emptyMsg = 'Image is empty (all zeros or NaN)';
        if isempty(report.failureReason)
            report.failureReason = emptyMsg;
        else
            report.failureReason = [report.failureReason '; ' emptyMsg];
        end
        if params.Verbose
            fprintf('FAILED (%s)\n', emptyMsg);
        end
    else
        if params.Verbose
            fprintf('PASSED\n');
        end
    end
    
    % Final validation result
    isValid = report.passed;
    
    if params.Verbose
        fprintf('=====================\n');
        if isValid
            fprintf('✓ Image validation PASSED\n');
        else
            fprintf('✗ Image validation FAILED: %s\n', report.failureReason);
        end
    end
end
