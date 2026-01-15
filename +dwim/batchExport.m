function T = batchExport(inputFolder)
    % BATCHEXPORT Processes a folder of DICOMs into a flattened table.
    
    arguments
        inputFolder (1,1) string = pwd
    end

    % 1. Use absolute paths to satisfy Bot standards
    if ~java.io.File(char(inputFolder)).isAbsolute()
        inputFolder = fullfile(pwd, inputFolder);
    end

    % 2. Get list of all DCM files
    files = dir(fullfile(inputFolder, '*.dcm'));
    if isempty(files)
        error('DWiM:NoFiles', 'No DICOM files found in %s', inputFolder);
    end

    fprintf('Processing %d files...\n', numel(files));
    allMetadata = cell(numel(files), 1);

    % 3. Loop through files using the Week 7 Safe Extraction
    for i = 1:numel(files)
        currentFile = fullfile(files(i).folder, files(i).name);
        try
            % This calls your extractMetadata which now handles sanitization/flattening
            allMetadata{i} = dwim.extractMetadata(currentFile);
        catch
            warning('DWiM:BatchWarning', 'Skipping corrupt file: %s', files(i).name);
            allMetadata{i} = struct(); % Placeholder for failed files
        end
    end

    % 4. Convert Cell Array of Structs to a Table
    % This handles varying fields across different DICOM files
    T = struct2table(allMetadata, 'AsArray', true);
    fprintf('Export Complete. Table generated with %d rows.\n', height(T));
end