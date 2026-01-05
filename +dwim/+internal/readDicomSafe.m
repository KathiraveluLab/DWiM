function [info, status] = readDicomSafe(filePath)
    % READDICOMSAFE Safely reads DICOM metadata with error handling.
    
    arguments
        filePath (1,1) string
    end

    % FIX: Machine-agnostic absolute path check using java.io.File
    if ~java.io.File(char(filePath)).isAbsolute()
        filePath = fullfile(pwd, filePath);
    end

    info = struct();
    status = struct('success', true, 'message', "");

    try
        if ~exist(filePath, 'file')
            error('File not found: %s', filePath);
        end
        % FIX: Removed unnecessary char() conversion for modern MATLAB
        info = dicominfo(filePath);
    catch ME
        status.success = false;
        status.message = string(ME.message);
        warning('DWiM:ReadError', 'Failed to read %s: %s', filePath, ME.message);
    end
end