function T = batchExport(folderPath)
    % BATCHEXPORT Scans a directory for DICOM files, extracts metadata,
    % and aggregates it into a single flattened MATLAB table.
    
    arguments
        folderPath (1,1) string
    end
    
    % 1. Find all DICOM files in the directory
    files = dir(fullfile(folderPath, '*.dcm'));
    if isempty(files)
        warning('DWiM:NoFiles', 'No .dcm files found in %s', folderPath);
        T = table();
        return;
    end
    
    numFiles = length(files);
    metaList = cell(numFiles, 1);
    
    fprintf('Batch processing %d files...\n', numFiles);
    
    % 2. Process each file (BOT FIX: Reintroduced parfor for parallel processing)
    parfor i = 1:numFiles
        filePath = fullfile(files(i).folder, files(i).name);
        try
            % extractMetadata already performs recursive flattening
            metaStruct = dwim.extractMetadata(filePath);
            metaList{i} = metaStruct;
        catch ME
            warning('DWiM:ExtractionFailed', 'Failed to process %s: %s', files(i).name, ME.message);
        end
    end
    
    % 3. Clean up any failed extractions
    metaList = metaList(~cellfun('isempty', metaList));
    
    % 4. Aggregate into a unified MATLAB Table
    try
        
        allFields = unique(vertcat(cellfun(@fieldnames, metaList, 'UniformOutput', false)));
        
        % Pad each struct with missing fields and guarantee identical field order
        for k = 1:length(metaList)
            missingFields = setdiff(allFields, fieldnames(metaList{k}));
            for m = 1:length(missingFields)
                metaList{k}.(missingFields{m}) = missing; 
            end
            % Order fields identically to prevent horizontal concatenation errors
            metaList{k} = orderfields(metaList{k}, allFields);
        end
        
        % Safely concatenate now that structure blueprints are identical
        combinedStruct = [metaList{:}];
        T = struct2table(combinedStruct, 'AsArray', true);
    catch ME
        error('DWiM:TableConversionFailed', 'Failed to aggregate batch data into a table: %s', ME.message);
    end
    
    fprintf('Batch export complete! Aggregated %d records.\n', height(T));
end