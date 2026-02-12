function outputFile = scrub(inputFile, outputFolder, profileName)
    % SCRUB Removes PHI based on a specific profile.
    % Usage: scrub(file, folder, 'strict')
    
    % --- ARGUMENTS BLOCK MUST BE FIRST ---
    arguments
        inputFile (1,1) string
        outputFolder (1,1) string = ""
        profileName (1,1) string = "strict" % Default to safest option
    end

    % Constants
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
    
    % Use string() casting to safely create filename
    filenameStr = string(f) + ANON_SUFFIX + string(ext);
    outputFile = fullfile(outputFolder, filenameStr);

    % 3. Get Profile Settings 
    % Retrieve the specific tags we want to force-update
    updateAttributes = dwim.anonymize.getProfile(profileName);

    % 4. Run Anonymization with Updates
    try
        % Pass the 'updateAttributes' struct to dicomanon
        % This tells it to overwrite specific tags while keeping others
        dicomanon(char(inputFile), char(outputFile), 'update', updateAttributes);
    catch ME
        error('DWiM:AnonymizeFailed', 'Failed to scrub file "%s": %s', inputFile, ME.message);
    end
    
    % 5. Verify Success
    if ~exist(outputFile, 'file')
        error('DWiM:WriteError', 'Anonymization ran but no file was created.');
    end
end