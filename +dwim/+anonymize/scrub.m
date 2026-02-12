function outputFile = scrub(inputFile, outputFolder, profileName)
    % SCRUB Removes PHI based on a specific profile.
    
    arguments
        inputFile (1,1) string
        outputFolder (1,1) string = ""
        profileName (1,1) string = "strict"
    end

    % Constants
    DEFAULT_SUBFOLDER = 'anonymized';
    ANON_SUFFIX = '_anon';

    % 1. Safety Check
    [~, status] = dwim.internal.readDicomSafe(inputFile);
    if ~status.success
        error('DWiM:ReadError', status.message);
    end

    % 2. Output Path
    [p, f, ext] = fileparts(inputFile);
    if outputFolder == ""
        outputFolder = fullfile(p, DEFAULT_SUBFOLDER);
    end
    if ~exist(outputFolder, 'dir')
        mkdir(outputFolder);
    end
    
    filenameStr = string(f) + ANON_SUFFIX + string(ext);
    outputFile = fullfile(outputFolder, filenameStr);

    % 3. Get Profile Settings
    % Now retrieves BOTH the update struct AND the keep list
    [updateAttributes, keepAttributes] = dwim.anonymize.getProfile(profileName);

    % 4. Run Anonymization
    try
        % We check if we have specific tags to keep.
        if isempty(keepAttributes)
            dicomanon(char(inputFile), char(outputFile), ...
                'update', updateAttributes);
        else
            % Pass the 'keep' argument to protect demographic data
            dicomanon(char(inputFile), char(outputFile), ...
                'update', updateAttributes, ...
                'keep', keepAttributes);
        end
    catch ME
        error('DWiM:AnonymizeFailed', 'Failed to scrub file "%s": %s', inputFile, ME.message);
    end
    
    % 5. Verify
    if ~exist(outputFile, 'file')
        error('DWiM:WriteError', 'Anonymization ran but no file was created.');
    end
end