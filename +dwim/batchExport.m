function T = batchExport(inputFolder)
    arguments
        inputFolder (1,1) string = ""
    end

    % Path discovery logic for CI
    if inputFolder == ""
        root = fileparts(fileparts(mfilename('fullpath')));
        inputFolder = fullfile(root, 'test_data');
    end

    files = dir(fullfile(inputFolder, '*.dcm'));
    numFiles = numel(files);
    allMetadata = cell(numFiles, 1);

    % Use parallel processing for improved multi-core performance
    parfor i = 1:numFiles
        currentFile = fullfile(files(i).folder, files(i).name);
        try
            allMetadata{i} = dwim.extractMetadata(currentFile);
        catch ME
            % Informative logging for easier debugging
            warning('DWiM:BatchWarning', 'Skipping %s. Reason: %s', files(i).name, ME.message);
            allMetadata{i} = struct(); 
        end
    end

    % FIX: Ensure cell array is a column for struct2table
    T = struct2table(reshape(allMetadata, [], 1), 'AsArray', true);
end