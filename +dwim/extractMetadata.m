function metadata = extractMetadata(dicomPath)
    % EXTRACTMETADATA Extracts and flattens DICOM metadata.
    
    arguments
        % If no path is provided, use the default test image
        dicomPath (1,1) string = fullfile(pwd, 'test_data', 'image01.dcm')
    end

    % Logic to ensure the file actually exists before proceeding
    if ~exist(dicomPath, 'file')
        error('DWiM:FileNotFound', 'The file %s does not exist.', dicomPath);
    end

    % Safe Read (Week 7 Logic)
    [rawInfo, status] = dwim.internal.readDicomSafe(dicomPath);
    
    if ~status.success
        error('DWiM:ReadError', status.message);
    end

    % Sanitize and Flatten (Week 6 & 7 Logic)
    cleanInfo = dwim.internal.sanitizeMetadata(rawInfo);
    metadata = dwim.internal.flattenStruct(cleanInfo);
end