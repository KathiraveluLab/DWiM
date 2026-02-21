function normalized = normalizeHU(image, windowCenter, windowWidth)
%NORMALIZEHU Normalize CT image using Hounsfield Unit windowing.
%
%   normalized = dwim.preprocess.normalizeHU(image, windowCenter, windowWidth)
%       Applies CT windowing to normalize pixel intensities based on HU values.
%
%   Inputs:
%       image        - CT image array (2D or 3D)
%       windowCenter - Center of the intensity window (HU)
%       windowWidth  - Width of the intensity window (HU)
%
%   Outputs:
%       normalized   - Normalized image with values in range [0, 1]
%
%   Example:
%       % Lung window (center=-600, width=1500)
%       lungImage = dwim.preprocess.normalizeHU(ctImage, -600, 1500);
%
%       % Brain window (center=40, width=80)
%       brainImage = dwim.preprocess.normalizeHU(ctImage, 40, 80);

    arguments
        image {mustBeNumeric}
        windowCenter (1,1) {mustBeNumeric}
        windowWidth (1,1) {mustBeNumeric, mustBePositive}
    end
    
    % Preserve input precision — single-precision arrays stay single for
    % memory efficiency in ML pipelines; all others promote to double.
    inputClass = class(image);
    if strcmp(inputClass, 'single')
        targetClass = 'single';
    else
        targetClass = 'double';
    end

    % Calculate window bounds
    minHU = windowCenter - (windowWidth / 2);
    maxHU = windowCenter + (windowWidth / 2);
    
    % Apply windowing
    normalized = double(image);

    % Replace non-finite values (NaN, Inf, -Inf) with the lower window bound
    % so they map to 0 after normalization rather than producing NaN output.
    nonFiniteMask = ~isfinite(normalized);
    if any(nonFiniteMask(:))
        normalized(nonFiniteMask) = minHU;
    end

    normalized = (normalized - minHU) / (maxHU - minHU);
    
    % Clip to [0, 1] range
    normalized = max(0, min(1, normalized));

    % Cast back to input precision
    normalized = cast(normalized, targetClass);
end
