function img = readPixels(dicomPath)
    % READPIXELS Extracts the raw pixel matrix from a DICOM file.
    
    arguments
        dicomPath (1,1) string
    end

    % 1. Use the Safe Reader from Week 7 to check the file first
    [info, status] = dwim.internal.readDicomSafe(dicomPath);
    if ~status.success
        error('DWiM:ReadError', status.message);
    end

    % 2. Read the raw pixels
    % We use char() for compatibility with older toolbox versions in CI
    img = dicomread(char(dicomPath));

    % 3. Apply Rescale Slope and Intercept if they exist
    % Formula: TrueValue = (Raw * Slope) + Intercept
    if isfield(info, 'RescaleSlope') && isfield(info, 'RescaleIntercept')
        slope = double(info.RescaleSlope);
        intercept = double(info.RescaleIntercept);
        img = double(img) .* slope + intercept;
    end
end