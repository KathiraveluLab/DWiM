function T = batchExport(inputFolder)
    % BATCHEXPORT Processes a folder of DICOMs into a flattened table.
    % High-performance engine with parallel processing and error logging.

    arguments
        % Default to the 'test_data' folder at project root if no folder provided
        inputFolder (1,1) string = ""
    end

    % 1. DYNAMIC PATH DISCOVERY (Fixes CI 'File not found' errors)
    % We find the root directory relative to this function's location
    if inputFolder == ""
        % Move up one level from +dwim/ to reach the project root
        packageDir = fileparts(mfilename('fullpath'));
        projectRoot = fileparts(packageDir);
        inputFolder = fullfile(projectRoot, 'test_data');
    end

    % 2. STANDARDIZE PATH (Bot Rule: Cross-platform compatibility)
    % Use java.io.File to check for absolute paths robustly
    if ~java.io.File(char(inputFolder)).isAbsolute()
        inputFolder = fullfile(pwd, inputFolder);
    end

    % 3. RETRIEVE FILE LIST
    files = dir(fullfile(inputFolder, '*.dcm'));
    if isempty(files)
        error('DWiM:NoFiles', 'No DICOM files found in directory: %s', inputFolder);
    end

    numFiles = numel(files);
    allMetadata = cell(numFiles, 1);

    % 4. PARALLEL PROCESSING (Bot Fix: Performance Optimization)
    % Processes files across multi-core systems if Parallel Toolbox is available
    fprintf('Processing %d files from: %s\n', numFiles, inputFolder);
    
    parfor i = 1:numFiles
        currentFile = fullfile(files(i).folder, files(i).name);
        try
            % Calls the sanitized/flattened extraction logic
            allMetadata{i} = dwim.extractMetadata(currentFile); 
        catch ME
            % Bot Fix: Captures full error message for easier debugging
            warning('DWiM:BatchWarning', 'Skipping %s. Reason: %s', files(i).name, ME.message);
            allMetadata{i} = struct(); % Placeholder to maintain table alignment
        end
    end

    % 5. SAFE TABLE CONVERSION
    % 'AsArray' allows table creation even if files have different numbers of tags
    T = struct2table(allMetadata, 'AsArray', true);
    fprintf('Batch Export Complete. Generated table with %d rows.\n', height(T));
end