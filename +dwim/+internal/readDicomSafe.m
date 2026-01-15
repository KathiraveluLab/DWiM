function [info, status] = readDicomSafe(filePath)
    arguments
        filePath (1,1) string
    end

    % Use java.io.File for robust cross-platform path check
    if ~java.io.File(char(filePath)).isAbsolute()
        filePath = fullfile(pwd, filePath);
    end

    info = struct();
    status = struct('success', true, 'message', "");

    try
        if ~exist(filePath, 'file')
            error('File not found: %s', filePath);
        end
        % Use char() for older MATLAB toolbox compatibility
        info = dicominfo(char(filePath));
    catch ME
        status.success = false;
        status.message = string(ME.message);
        warning('DWiM:ReadError', 'Failed to read %s: %s', filePath, ME.message);
    end
end