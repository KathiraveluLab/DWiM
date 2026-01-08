function outputPath = convertToPNG(inputFile, outputDir, options)
%convertToPNG Convert a DICOM file to PNG format.
%
%   outputPath = dwim.convertToPNG(inputFile)
%       Converts a DICOM file to PNG and saves it in the same directory.
%
%   outputPath = dwim.convertToPNG(inputFile, outputDir)
%       Converts and saves the PNG to the specified output directory.
%
%   outputPath = dwim.convertToPNG(inputFile, outputDir, Name=Value)
%       Additional options to customize the conversion.
%
%   Inputs:
%       inputFile  - (string) Path to the source DICOM file.
%       outputDir  - (string) Directory for the output PNG file.
%
%   Name-Value Arguments:
%       BitDepth      - (8 or 16) Output bit depth. Default: 8.
%       WindowCenter  - (double) Window center for contrast. Default: auto.
%       WindowWidth   - (double) Window width for contrast. Default: auto.
%       Normalize     - (logical) Normalize to full intensity range. Default: true.
%       OutputName    - (string) Custom output filename (without extension).
%
%   Outputs:
%       outputPath - (string) Full path to the created PNG file.
%
%   Example:
%       % Basic conversion
%       dwim.convertToPNG('scan.dcm', 'output/');
%
%       % 16-bit output with custom windowing
%       dwim.convertToPNG('scan.dcm', 'output/', BitDepth=16, ...
%           WindowCenter=40, WindowWidth=400);

    arguments
        inputFile  (1,1) string
        outputDir  (1,1) string = ""
        options.BitDepth     (1,1) double {mustBeMember(options.BitDepth, [8, 16])} = 8
        options.WindowCenter (1,1) double = NaN
        options.WindowWidth  (1,1) double = NaN
        options.Normalize    (1,1) logical = true
        options.OutputName   (1,1) string = ""
    end

    % 1. Validate input file exists
    if ~isfile(inputFile)
        error('dwim:convertToPNG:FileNotFound', ...
              'The input file "%s" was not found.', inputFile);
    end

    % 2. Set default output directory to input file's directory
    if outputDir == ""
        path = fileparts(inputFile);
        if path == ""
            outputDir = string(pwd);
        else
            outputDir = string(path);
        end
    end

    % 3. Ensure output directory exists
    if ~isfolder(outputDir)
        mkdir(outputDir);
    end

    % 4. Read DICOM image and metadata
    try
        img = dicomread(inputFile);
        info = dicominfo(inputFile);
    catch ME
        error('dwim:convertToPNG:ReadFailed', ...
              'Failed to read DICOM file: %s', ME.message);
    end

    % 5. Convert to double for processing
    img = double(img);

    % 6. Determine window/level values
    [winCenter, winWidth] = getWindowValues(img, info, options);

    % 7. Apply windowing transform
    imgWindowed = applyWindowing(img, winCenter, winWidth);

    % 8. Normalize if requested
    if options.Normalize
        imgWindowed = normalizeImage(imgWindowed);
    end

    % 9. Convert to output bit depth
    if options.BitDepth == 8
        imgOut = uint8(imgWindowed * 255);
    else
        imgOut = uint16(imgWindowed * 65535);
    end

    % 10. Generate output filename
    if options.OutputName ~= ""
        outputName = options.OutputName;
    else
        [~, outputName, ~] = fileparts(inputFile);
    end
    outputPath = fullfile(outputDir, outputName + ".png");

    % 11. Write PNG file
    try
        imwrite(imgOut, outputPath, 'BitDepth', options.BitDepth);
    catch ME
        error('dwim:convertToPNG:WriteFailed', ...
              'Failed to write PNG file: %s', ME.message);
    end
end

%% Helper Functions

function [winCenter, winWidth] = getWindowValues(img, info, options)
%getWindowValues Determine window center and width for contrast adjustment.

    % Use provided values if specified
    if ~isnan(options.WindowCenter) && ~isnan(options.WindowWidth)
        winCenter = options.WindowCenter;
        winWidth = options.WindowWidth;
        return;
    end

    % Try to get from DICOM header
    if isfield(info, 'WindowCenter') && isfield(info, 'WindowWidth')
        wc = info.WindowCenter;
        ww = info.WindowWidth;
        
        % Handle multiple windows (use first)
        if numel(wc) > 1
            winCenter = wc(1);
            winWidth = ww(1);
        else
            winCenter = wc;
            winWidth = ww;
        end
        return;
    end

    % Calculate from image data
    minVal = min(img(:));
    maxVal = max(img(:));
    winCenter = (maxVal + minVal) / 2;
    winWidth = maxVal - minVal;
    
    % Avoid zero width
    if winWidth == 0
        winWidth = 1;
    end
end

function imgOut = applyWindowing(img, winCenter, winWidth)
%applyWindowing Apply window/level transform to image.

    % Handle zero or negative width window to avoid division by zero
    if winWidth <= 0
        imgOut = double(img >= winCenter);
    else
        % Calculate window boundaries
        winMin = winCenter - winWidth / 2;
        winMax = winCenter + winWidth / 2;

        % Apply linear windowing
        imgOut = (img - winMin) / (winMax - winMin);
    end

    % Clamp to [0, 1]
    imgOut = max(0, min(1, imgOut));
end

function imgOut = normalizeImage(img)
%normalizeImage Normalize image to use full [0, 1] range.

    minVal = min(img(:));
    maxVal = max(img(:));
    
    if maxVal > minVal
        imgOut = (img - minVal) / (maxVal - minVal);
    else
        imgOut = img;
    end
end
