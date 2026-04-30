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

    % Handle flat images (intensity range = 0) to avoid slider errors
    minVal = min(img(:)); 
    maxVal = max(img(:));
    
    if minVal == maxVal
        minVal = minVal - 0.5;
        maxVal = maxVal + 0.5;
    end

    defaultLevel = (maxVal + minVal) / 2;
    defaultWidth = maxVal - minVal;

    % Level Slider
    uicontrol('Style', 'text', 'Position', [20, 45, 100, 20], 'String', 'Level');
    lvlSld = uicontrol('Style', 'slider', 'Min', minVal, 'Max', maxVal, ...
        'Value', defaultLevel, 'Position', [120, 45, 200, 20]);

    % Width Slider (Min value of 0.1 prevents zero-width issues)
    uicontrol('Style', 'text', 'Position', [20, 20, 100, 20], 'String', 'Width');
    wthSld = uicontrol('Style', 'slider', 'Min', 0.1, 'Max', max(1, defaultWidth*2), ...
        'Value', max(0.1, defaultWidth), 'Position', [120, 20, 200, 20]);

    % Callbacks
    callback = @(~,~) updateCLim(ax, lvlSld.Value, wthSld.Value);
    lvlSld.Callback = callback;
    wthSld.Callback = callback;
    
    updateCLim(ax, defaultLevel, defaultWidth);
end

function updateCLim(ax, level, width)
    % Removed redundant unreachable code per bot feedback
    set(ax, 'CLim', [level - width/2, level + width/2]);
end