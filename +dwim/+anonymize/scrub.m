function outputFile = scrub(inputFile, outputFolder)
    % SCRUB Removes standard PHI (Patient Health Info) from a DICOM file.
    % Usage: scrub('path/to/image.dcm', 'path/to/output_folder')
    
    arguments
        inputFile (1,1) string
        outputFolder (1,1) string = ""
    end

    % Constants for maintainability
    DEFAULT_SUBFOLDER = 'anonymized';
    ANON_SUFFIX = '_anon';

    % 1. Safety Check
    [~, status] = dwim.internal.readDicomSafe(inputFile);
    if ~status.success
        error('DWiM:ReadError', status.message);
    end

    % 2. Determine Output Path
    [p, f, ext] = fileparts(inputFile);
    
    if outputFolder == ""
        outputFolder = fullfile(p, DEFAULT_SUBFOLDER);
    end
    
    if ~exist(outputFolder, 'dir')
        mkdir(outputFolder);
    end
    
    % fileparts returns chars, so we use string() to ensure '+' joins them textually
    filenameStr = string(f) + ANON_SUFFIX + string(ext);
    outputFile = fullfile(outputFolder, filenameStr);

    % 3. Run Anonymization
    try
        dicomanon(char(inputFile), char(outputFile));
    catch ME
        error('DWiM:AnonymizeFailed', 'Failed to scrub file "%s": %s', inputFile, ME.message);
    end
    
    % 4. Verify Success
    if ~exist(outputFile, 'file')
        error('DWiM:WriteError', 'Anonymization ran but no file was created.');
    end
end