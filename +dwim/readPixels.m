function img = readPixels(dicomPath)
    arguments
        dicomPath (1,1) string
    end

    [info, status] = dwim.internal.readDicomSafe(dicomPath);
    if ~status.success
        error('DWiM:ReadError', status.message);
    end

    % Bot Fix: Check for empty returns from dicomread
    img = dicomread(char(dicomPath));
    if isempty(img)
        error('DWiM:ReadError:EmptyPixels', ...
            'Failed to read pixel data from %s. dicomread returned an empty matrix.', dicomPath);
    end

    % Apply scaling logic
    if isfield(info, 'RescaleSlope') && isfield(info, 'RescaleIntercept')
        img = double(img) .* double(info.RescaleSlope) + double(info.RescaleIntercept);
    end
end