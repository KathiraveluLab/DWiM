function [isValid, info] = validateImageForML(image, varargin)
%VALIDATEIMAGEFORML Validate DICOM image for ML preprocessing.
%
%   [isValid, info] = dwim.preprocess.validateImageForML(image)
%       Validates if a DICOM image is suitable for ML preprocessing.
%
%   [isValid, info] = dwim.preprocess.validateImageForML(image, 'MinSize', [256, 256])
%       Validates with custom minimum size requirements.
%
%   Inputs:
%       image   - Image array (2D or 3D)
%
%   Name-Value Arguments:
%       MinSize - Minimum required dimensions [height, width] (default: [128, 128])
%       MaxSize - Maximum allowed dimensions [height, width] (default: [2048, 2048])
%
%   Outputs:
%       isValid - Logical indicating if image passes validation
%       info    - Structure with validation details and recommendations
%
%   Example:
%       [valid, details] = dwim.preprocess.validateImageForML(ctImage);
%       if ~valid
%           fprintf('Issues: %s\n', strjoin(details.issues, ', '));
%       end

    arguments
        image {mustBeNumeric}
    end
    
    arguments (Repeating)
        varargin
    end
    
    % Parse optional arguments
    p = inputParser;
    addParameter(p, 'MinSize', [128, 128], @(x) isnumeric(x) && length(x) == 2);
    addParameter(p, 'MaxSize', [2048, 2048], @(x) isnumeric(x) && length(x) == 2);
    parse(p, varargin{:});
    
    minSize = p.Results.MinSize;
    maxSize = p.Results.MaxSize;
    
    % Initialize validation results
    isValid = true;
    issues = {};
    warnings = {};
    recommendations = {};
    
    % Get image dimensions
    [height, width, depth] = size(image);
    
    % Check 1: Image dimensions
    if height < minSize(1) || width < minSize(2)
        isValid = false;
        issues{end+1} = sprintf('Image too small (%dx%d), minimum required: %dx%d', ...
            height, width, minSize(1), minSize(2));
        recommendations{end+1} = 'Consider upsampling or using different image';
    end
    
    if height > maxSize(1) || width > maxSize(2)
        warnings{end+1} = sprintf('Image very large (%dx%d), may need downsampling', height, width);
        recommendations{end+1} = 'Consider downsampling for faster processing';
    end
    
    % Check 2: Data type and range
    if ~isa(image, 'double') && ~isa(image, 'single') && ~isa(image, 'int16') && ~isa(image, 'uint16')
        warnings{end+1} = sprintf('Unusual data type: %s', class(image));
        recommendations{end+1} = 'Convert to double or int16 for CT processing';
    end
    
    % Check 3: Value range (typical for CT)
    minVal = double(min(image(:)));
    maxVal = double(max(image(:)));
    
    if minVal >= 0 && maxVal <= 255
        warnings{end+1} = 'Values in [0,255] range - may be pre-windowed or not raw HU';
        recommendations{end+1} = 'Verify if this is raw DICOM data or pre-processed';
    elseif minVal < -2000 || maxVal > 4000
        warnings{end+1} = sprintf('Unusual HU range: [%.1f, %.1f]', minVal, maxVal);
        recommendations{end+1} = 'Check if values are in Hounsfield Units';
    end
    
    % Check 4: Image content
    if std(double(image(:))) < 1
        isValid = false;
        issues{end+1} = 'Image has very low variance - may be blank or corrupted';
        recommendations{end+1} = 'Check DICOM file integrity';
    end
    
    % Check 5: 3D volume considerations
    if depth > 1
        warnings{end+1} = sprintf('3D volume with %d slices detected', depth);
        recommendations{end+1} = 'Consider slice-by-slice processing or volume-based ML models';
    end
    
    % Compile results
    info = struct();
    info.dimensions = [height, width, depth];
    info.dataType = class(image);
    info.valueRange = [minVal, maxVal];
    info.variance = std(double(image(:)));
    info.issues = issues;
    info.warnings = warnings;
    info.recommendations = recommendations;
    info.isValid = isValid;
    
    % Overall assessment
    if isValid && isempty(warnings)
        info.assessment = 'Image is ready for ML preprocessing';
    elseif isValid
        info.assessment = 'Image is valid but has minor concerns';
    else
        info.assessment = 'Image has issues that need to be addressed';
    end
end