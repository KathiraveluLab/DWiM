function [info, status] = readDicomSafe(filePath)
    % READDICOMSAFE Safely reads DICOM metadata with error handling.
    % Path: C:\Users\surya\DWiM\+dwim\+internal\readDicomSafe.m

    arguments
        filePath (1,1) string
    end

    % Bot Rule: Ensure absolute paths
    if ~startsWith(filePath, "C:") && ~startsWith(filePath, "/")
        filePath = fullfile(pwd, filePath);
    end

    info = struct();
    status = struct('success', true, 'message', "");

    try
        if ~exist(filePath, 'file')
            error('File not found: %s', filePath);
        end
        info = dicominfo(char(filePath));
    catch ME
        status.success = false;
        status.message = string(ME.message);
        % Log error instead of crashing (Best practice for batch processing)
        warning('DWiM:ReadError', 'Failed to read %s: %s', filePath, ME.message);
    end
end