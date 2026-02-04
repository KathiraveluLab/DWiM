function outputFile = scrub(inputFile, outputFolder)
    % SCRUB Removes standard PHI (Patient Health Info) from a DICOM file.
    % Usage: scrub('path/to/image.dcm', 'path/to/output_folder')
    
    arguments
        inputFile (1,1) string
        outputFolder (1,1) string = ""
    end

    % 1. Safety Check
    [~, status] = dwim.internal.readDicomSafe(inputFile);
    if ~status.success
        error('DWiM:ReadError', status.message);
    end

    % 2. Determine Output Path
    % If no folder provided, create a 'anonymized' subfolder
    [p, f, ext] = fileparts(inputFile);
    if outputFolder == ""
        outputFolder = fullfile(p, 'anonymized');
    end
    
    if ~exist(outputFolder, 'dir')
        mkdir(outputFolder);
    end
    
    outputFile = fullfile(outputFolder, f + "_anon" + ext);

    % 3. Run Anonymization
    try
        % dicomanon removes PatientName, PatientID, etc. by default.
        dicomanon(char(inputFile), char(outputFile));
    catch ME
        error('DWiM:AnonymizeFailed', 'Failed to scrub file: %s', ME.message);
    end
    
    % 4. Verify Success
    if ~exist(outputFile, 'file')
        error('DWiM:WriteError', 'Anonymization ran but no file was created.');
    end
end