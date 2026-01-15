function T = batchExport(inputFolder)
    % BATCHEXPORT Processes a folder of DICOMs into a flattened table.
    
    arguments
        inputFolder (1,1) string = pwd
    end

    % FIX: Machine-agnostic absolute path check
    if ~java.io.File(char(inputFolder)).isAbsolute()
        inputFolder = fullfile(pwd, inputFolder);
    end

    % Get list of all DCM files
    files = dir(fullfile(inputFolder, '*.dcm'));
    if isempty(files)
        error('DWiM:NoFiles', 'No DICOM files found in %s', inputFolder);
    end

    numFiles = numel(files);
    allMetadata = cell(numFiles, 1);

    % BOT FIX: Use parfor for multi-core performance and capture ME for logging
    % Note: If Parallel Toolbox is missing, this automatically runs as a standard loop.
    parfor i = 1:numFiles
        currentFile = fullfile(files(i).folder, files(i).name);
        try
            allMetadata{i} = dwim.extractMetadata(currentFile);
        catch ME
            % BOT FIX: Include the specific error message for easier debugging
            warning('DWiM:BatchWarning', 'Skipping %s. Reason: %s', files(i).name, ME.message);
            allMetadata{i} = struct(); 
        end
    end

    % Convert to Table (using 'AsArray' to handle diverse field sets)
    T = struct2table(allMetadata, 'AsArray', true);
end