function [info, status] = readDicomSafe(filePath)
    arguments
        filePath (1,1) string
    end

    % Use java.io.File for robust path detection
    if ~java.io.File(char(filePath)).isAbsolute()
        filePath = fullfile(pwd, filePath);
    end

    info = struct();
    status = struct('success', true, 'message', "");

    try
        if ~exist(filePath, 'file')
            error('DWiM:FileNotFound', 'File not found: %s', filePath);
        end
        
        % Check for toolbox presence to avoid Undefined Function errors
        if isempty(which('dicominfo'))
            error('DWiM:ToolboxMissing', 'Image Processing Toolbox (dicominfo) is not installed.');
        end
        
        info = dicominfo(char(filePath)); % Explicit char for older versions
    catch ME
        status.success = false;
        status.message = string(ME.message);
        warning('DWiM:ReadError', 'Failed to read %s: %s', filePath, ME.message);
    end
end