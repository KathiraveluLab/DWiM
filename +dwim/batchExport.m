function T = batchExport(inputFolder)
    arguments
        inputFolder (1,1) string = ""
    end

    % Path Discovery
    if inputFolder == ""
        root = fileparts(fileparts(mfilename('fullpath')));
        inputFolder = fullfile(root, 'test_data');
    end

    files = dir(fullfile(inputFolder, '*.dcm'));
    numFiles = numel(files);
    allMetadata = cell(numFiles, 1);

    % Use parfor for performance
    parfor i = 1:numFiles
        currentFile = fullfile(files(i).folder, files(i).name);
        try
            allMetadata{i} = dwim.extractMetadata(currentFile);
        catch ME
            % Log specific error message
            warning('DWiM:BatchWarning', 'Skipping %s: %s', files(i).name, ME.message);
            allMetadata{i} = struct(); 
        end
    end

    % FIX: Convert cell array of structs to a struct array safely
    structArray = [allMetadata{:}];
    if isempty(structArray)
        T = table();
    else
        T = struct2table(structArray, 'AsArray', true);
    end
end