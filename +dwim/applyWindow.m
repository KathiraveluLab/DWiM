function adjustedImg = applyWindow(img, level, width)
    % APPLYWINDOW Maps pixel intensities to a specific display range.
    
    arguments
        img (:,:) double
        level (1,1) double
        % Enforce non-negative width to prevent logical errors
        width (1,1) double {mustBeNonnegative} 
    end

    % 1. Calculate the bounds
    lowerBound = level - (width / 2);
    upperBound = level + (width / 2);

    % 2. Clip and Normalize
    % Use 'eps' to safely handle zero-width cases without crashing
    adjustedImg = (img - lowerBound) / (upperBound - lowerBound + eps);
    
    % Use concise min/max for clipping to [0, 1] range
    adjustedImg = max(0, min(1, adjustedImg));
end