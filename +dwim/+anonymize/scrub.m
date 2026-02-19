function outputFile = scrub(inputFile, outputFolder, profileName, mapper)
    % SCRUB Removes PHI based on a specific profile, with optional UID remapping.
    
    arguments
        inputFile (1,1) string
        outputFolder (1,1) string = ""
        profileName (1,1) string = "strict"
        mapper = [] % Optional dwim.anonymize.UidMapper object
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
    
    filenameStr = string(f) + ANON_SUFFIX + string(ext);
    outputFile = fullfile(outputFolder, filenameStr);

    % 3. Get Profile Settings
    [updateAttributes, keepAttributes] = dwim.anonymize.getProfile(profileName);
    
    % Handles mapped vs random logic centrally to avoid redundant generation
    if lower(profileName) == "research"
        if ~isempty(mapper)
            % Peek at the original file to get the real ID
            meta = dicominfo(char(inputFile));
            if isfield(meta, 'PatientID')
                updateAttributes.PatientID = mapper.getNewId(meta.PatientID, "RES_");
            else
                % Fallback if file has no ID
                updateAttributes.PatientID = ['RES_' char(java.util.UUID.randomUUID)];
            end
        else
            % Fallback: Generate a random ID if no mapper is provided
            updateAttributes.PatientID = ['RES_' char(java.util.UUID.randomUUID)];
        end
    end

    % 4. Run Anonymization
    try
        if isempty(keepAttributes)
            dicomanon(char(inputFile), char(outputFile), 'update', updateAttributes);
        else
            dicomanon(char(inputFile), char(outputFile), 'update', updateAttributes, 'keep', keepAttributes);
        end
    catch ME
        error('DWiM:AnonymizeFailed', 'Failed to scrub file "%s": %s', inputFile, ME.message);
    end
    
    % 5. Verify Success
    if ~exist(outputFile, 'file')
        error('DWiM:WriteError', 'Anonymization ran but no file was created.');
    end
end