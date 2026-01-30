function adjustedImg = applyWindow(img, level, width)
    % APPLYWINDOW Maps pixel intensities to a specific display range.
    % Formula: [Level - Width/2, Level + Width/2] maps to [0, 1]
    
    arguments
        img (:,:) double
        level (1,1) double
        width (1,1) double
    end

    % 1. Calculate the bounds
    lowerBound = level - (width / 2);
    upperBound = level + (width / 2);

    % 2. Clip and Normalize
    adjustedImg = (img - lowerBound) / (upperBound - lowerBound);
    adjustedImg(adjustedImg < 0) = 0; % Force values below window to black
    adjustedImg(adjustedImg > 1) = 1; % Force values above window to white
end