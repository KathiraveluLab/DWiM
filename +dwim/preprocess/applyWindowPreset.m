function windowed = applyWindowPreset(image, preset)
%APPLYWINDOWPRESET Apply standard windowing presets to medical images
%
%   windowed = applyWindowPreset(image, preset)
%       Applies a predefined windowing preset to normalize the image
%
%   Inputs:
%       image - 2D or 3D numeric array (typically HU values for CT)
%       preset - String specifying the preset:
%                'lung'  - Lung window (C=-600, W=1500)
%                'soft'  - Soft tissue window (C=40, W=400)
%                'bone'  - Bone window (C=300, W=1500)
%                'brain' - Brain window (C=40, W=80)
%                'liver' - Liver window (C=30, W=150)
%
%   Outputs:
%       windowed - Image normalized to [0,1] range
%
%   Example:
%       % Apply lung windowing
%       lungImage = dwim.preprocess.applyWindowPreset(ctSlice, 'lung');
%
%       % Apply bone windowing
%       boneImage = dwim.preprocess.applyWindowPreset(ctSlice, 'bone');

    arguments
        image {mustBeNumeric}
        preset (1,:) char {mustBeMember(preset, {'lung', 'soft', 'bone', 'brain', 'liver'})}
    end
    
    % Define window presets (Center, Width)
    presets = struct();
    presets.lung = struct('center', -600, 'width', 1500);
    presets.soft = struct('center', 40, 'width', 400);
    presets.bone = struct('center', 300, 'width', 1500);
    presets.brain = struct('center', 40, 'width', 80);
    presets.liver = struct('center', 30, 'width', 150);
    
    % Get preset parameters
    windowParams = presets.(preset);
    
    % Apply windowing using normalizeHU
    windowed = dwim.preprocess.normalizeHU(image, windowParams.center, windowParams.width);
end
