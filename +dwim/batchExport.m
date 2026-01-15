function T = batchExport(inputFolder)
    arguments
        inputFolder (1,1) string = ""
    end

    % Path Discovery
    if inputFolder == ""
        packagePath = fileparts(mfilename('fullpath'));
        projectRoot = fileparts(packagePath);
        inputFolder = fullfile(projectRoot, 'test_data');
    end

    files = dir(fullfile(inputFolder, '*.dcm'));
    numFiles = numel(files);
    allMetadata = cell(numFiles, 1);

    % Performance Optimization: Parallel Loop
    parfor i = 1:numFiles
        currentFile = fullfile(files(i).folder, files(i).name);
        try
            allMetadata{i} = dwim.extractMetadata(currentFile);
        catch ME
            warning('DWiM:BatchWarning', 'Skipping %s: %s', files(i).name, ME.message);
            allMetadata{i} = struct(); 
        end
    end

    % Convert to Table (Safe handling of diverse fields)
    % Filter out any empty entries before conversion
    validEntries = allMetadata(~cellfun(@isempty, allMetadata));
    if isempty(validEntries)
        T = table();
    else
        % Convert cell of structs to a struct array for struct2table
        T = struct2table([validEntries{:}], 'AsArray', true);
    end
end