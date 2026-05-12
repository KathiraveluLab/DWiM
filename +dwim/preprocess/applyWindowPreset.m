function windowed = applyWindowPreset(image, presetName)
%APPLYWINDOWPRESET Apply standard CT windowing presets.
%
%   windowed = dwim.preprocess.applyWindowPreset(image, presetName)
%       Applies predefined CT windowing presets for common anatomical regions.
%
%   Inputs:
%       image      - CT image array (2D or 3D)
%       presetName - Name of windowing preset (string)
%                    Options: 'lung', 'brain', 'abdomen', 'bone', 'mediastinum'
%
%   Outputs:
%       windowed   - Windowed image with values in range [0, 1]
%
%   Example:
%       lungView = dwim.preprocess.applyWindowPreset(ctImage, 'lung');
%       brainView = dwim.preprocess.applyWindowPreset(ctImage, 'brain');

    arguments
        image {mustBeNumeric}
        presetName (1,1) string {mustBeMember(presetName, ...
            ["lung", "brain", "abdomen", "bone", "mediastinum"])}
    end
    
    % Define standard windowing presets (center, width)
    presets = struct(...
        'lung',       struct('center', -600, 'width', 1500), ...
        'brain',      struct('center', 40,   'width', 80), ...
        'abdomen',    struct('center', 40,   'width', 400), ...
        'bone',       struct('center', 400,  'width', 1800), ...
        'mediastinum', struct('center', 50,  'width', 350));
    
    % Get preset parameters
    preset = presets.(presetName);
    
    % Apply windowing using normalizeHU
    windowed = dwim.preprocess.normalizeHU(image, preset.center, preset.width);
end
