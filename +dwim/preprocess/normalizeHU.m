function normalized = normalizeHU(image, windowCenter, windowWidth)
%NORMALIZEHU Normalize Hounsfield Unit (HU) values to [0,1] range
%
%   normalized = normalizeHU(image, windowCenter, windowWidth)
%       Applies window/level normalization to CT image data
%
%   Inputs:
%       image - 2D or 3D numeric array with HU values
%       windowCenter - Center of the window in HU (e.g., -600 for lung)
%       windowWidth - Width of the window in HU (e.g., 1500 for lung)
%
%   Outputs:
%       normalized - Image normalized to [0,1] range
%
%   Example:
%       % Lung window normalization
%       normalized = dwim.preprocess.normalizeHU(ctSlice, -600, 1500);
%
%       % Soft tissue window
%       normalized = dwim.preprocess.normalizeHU(ctSlice, 40, 400);

    arguments
        image {mustBeNumeric}
        windowCenter (1,1) {mustBeNumeric}
        windowWidth (1,1) {mustBeNumeric, mustBePositive}
    end
    
    % Calculate window bounds
    windowMin = windowCenter - (windowWidth / 2);
    windowMax = windowCenter + (windowWidth / 2);
    
    % Convert to double for precision
    image = double(image);
    
    % Apply windowing
    normalized = (image - windowMin) / (windowMax - windowMin);
    
    % Clip to [0,1] range
    normalized = max(0, min(1, normalized));
end
