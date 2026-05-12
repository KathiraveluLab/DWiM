function metadata = extractMetadata(dicomPath)
    arguments
        dicomPath (1,1) string
    end

    % 1. Safe Read
    [rawInfo, status] = dwim.internal.readDicomSafe(dicomPath);
    if ~status.success
        error('DWiM:ReadError', status.message);
    end

    % 2. Sanitize (Week 7 fix)
    cleanInfo = dwim.internal.sanitizeMetadata(rawInfo);

    % 3. Flatten (Week 6 fix)
    metadata = dwim.internal.flattenStruct(cleanInfo);
end