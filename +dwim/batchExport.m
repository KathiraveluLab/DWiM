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
    
    % 2. Process each file 
    % (Note: This is the standard loop. We will upgrade this in GSoC!)
    for i = 1:numFiles
        filePath = fullfile(files(i).folder, files(i).name);
        try
            % Extract metadata using your existing engine
            metaStruct = dwim.extractMetadata(filePath);
            
            % Flatten nested structs to ensure clean table generation
            metaList{i} = flattenStruct(metaStruct);
        catch ME
            warning('DWiM:ExtractionFailed', 'Failed to process %s: %s', files(i).name, ME.message);
        end
    end
    
    % 3. Clean up any failed extractions
    metaList = metaList(~cellfun('isempty', metaList));
    
    % 4. Aggregate into a unified MATLAB Table
    try
        combinedStruct = [metaList{:}];
        T = struct2table(combinedStruct, 'AsArray', true);
    catch ME
        error('DWiM:TableConversionFailed', 'Failed to aggregate batch data into a table: %s', ME.message);
    end
    
    fprintf('Batch export complete! Aggregated %d records.\n', height(T));
end

% --- Helper Function ---
function flatStruct = flattenStruct(inStruct, prefix)
    % Recursively flattens nested structures into a single-level struct.
    if nargin < 2
        prefix = '';
    end
    flatStruct = struct();
    fields = fieldnames(inStruct);
    
    for i = 1:length(fields)
        fName = fields{i};
        val = inStruct.(fName);
        
        % Create new field name (append prefix if nested)
        if ~isempty(prefix)
            newFName = [prefix, '_', fName];
        else
            newFName = fName;
        end
        
        if isstruct(val)
            % Recursive call for nested structs
            subStruct = flattenStruct(val, newFName);
            subFields = fieldnames(subStruct);
            for j = 1:length(subFields)
                flatStruct.(subFields{j}) = subStruct.(subFields{j});
            end
        else
            % Assign flat value
            flatStruct.(newFName) = val;
        end
    end
end