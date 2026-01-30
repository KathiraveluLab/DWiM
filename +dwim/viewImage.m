function viewImage(img, titleStr)
    arguments
        img (:,:) double
        titleStr (1,1) string = "DICOM Preview"
    end

    f = figure('Name', 'Interactive DICOM Viewer');
    ax = axes('Parent', f);
    hImg = imagesc(img, 'Parent', ax);
    colormap gray; axis image; colorbar;
    title(titleStr, 'Interpreter', 'none');

    % Handle flat images (intensity range = 0) to avoid slider/CLim errors
    minVal = min(img(:)); 
    maxVal = max(img(:));
    
    if minVal == maxVal
        % Add a small buffer if the image is a single flat value
        minVal = minVal - 0.5;
        maxVal = maxVal + 0.5;
    end

    defaultLevel = (maxVal + minVal) / 2;
    defaultWidth = maxVal - minVal;

    % Level Slider
    uicontrol('Style', 'text', 'Position', [20, 45, 100, 20], 'String', 'Level');
    lvlSld = uicontrol('Style', 'slider', 'Min', minVal, 'Max', maxVal, ...
        'Value', defaultLevel, 'Position', [120, 45, 200, 20]);

    % Width Slider (Ensure Min is always positive)
    uicontrol('Style', 'text', 'Position', [20, 20, 100, 20], 'String', 'Width');
    wthSld = uicontrol('Style', 'slider', 'Min', 0.1, 'Max', max(1, defaultWidth*2), ...
        'Value', max(0.1, defaultWidth), 'Position', [120, 20, 200, 20]);

    % Callback with safety check to ensure lower bound < upper bound
    callback = @(~,~) updateCLim(ax, lvlSld.Value, wthSld.Value);
    lvlSld.Callback = callback;
    wthSld.Callback = callback;
    
    % Initialize display range
    updateCLim(ax, defaultLevel, defaultWidth);
end

function updateCLim(ax, level, width)
    % Helper to safely set CLim without crashing on zero-width
    low = level - width/2;
    high = level + width/2;
    if low == high
        high = low + 0.01; % Smallest possible width to keep CLim happy
    end
    set(ax, 'CLim', [low, high]);
end