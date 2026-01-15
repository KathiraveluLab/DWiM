function T = batchExport(inputFolder)
    % BATCHEXPORT Processes a folder of DICOMs into a flattened table.
    
    arguments
        inputFolder (1,1) string = ""
    end

    % 1. DYNAMIC ROOT DISCOVERY
    % Find project root relative to this function's location (+dwim/batchExport.m)
    if inputFolder == ""
        packagePath = fileparts(mfilename('fullpath'));
        projectRoot = fileparts(packagePath);
        inputFolder = fullfile(projectRoot, 'test_data');
    end

    % 2. STANDARDIZE PATH
    % Machine-agnostic absolute path check using java.io.File
    if ~java.io.File(char(inputFolder)).isAbsolute()
        inputFolder = fullfile(pwd, inputFolder);
    end

    % 3. RETRIEVE AND VALIDATE FILES
    files = dir(fullfile(inputFolder, '*.dcm'));
    if isempty(files)
        error('DWiM:NoFiles', 'No DICOM files found in directory: %s', inputFolder);
    end

    numFiles = numel(files);
    allMetadata = cell(numFiles, 1);

    % 4. PERFORMANCE OPTIMIZATION: PARFOR
    % Parallel file processing with captured exception objects for logging
    parfor i = 1:numFiles
        currentFile = fullfile(files(i).folder, files(i).name);
        try
            allMetadata{i} = dwim.extractMetadata(currentFile);
        catch ME
            warning('DWiM:BatchWarning', 'Skipping %s. Reason: %s', files(i).name, ME.message);
            allMetadata{i} = struct(); 
        end
    end

    % 5. SAFE TABLE CONVERSION
    T = struct2table(allMetadata, 'AsArray', true);
end