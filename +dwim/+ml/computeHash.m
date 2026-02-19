function hash = computeHash(data)
%COMPUTEHASH Compute MD5 hash of data
%
%   hash = dwim.ml.computeHash(data)
%       Computes MD5 hash for any MATLAB data type
%
%   Inputs:
%       data - Any MATLAB data (numeric, struct, cell, etc.)
%
%   Outputs:
%       hash - MD5 hash string

    % Serialize data to handle all MATLAB data types robustly
    tempFile = [tempname '.mat'];
    cleanup = onCleanup(@() delete(tempFile));
    save(tempFile, 'data', '-v7.3');
    
    fid = fopen(tempFile, 'r');
    dataBytes = fread(fid, inf, '*uint8');
    fclose(fid);
    
    md = java.security.MessageDigest.getInstance('MD5');
    md.update(dataBytes);
    hashBytes = md.digest();
    hash = sprintf('%02x', typecast(hashBytes, 'uint8'));
end
