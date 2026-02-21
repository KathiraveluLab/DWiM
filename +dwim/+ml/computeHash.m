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

    % Serialize data to a byte stream via a temporary file.
    % This avoids reliance on undocumented internal functions like
    % getByteStreamFromArray, which may be removed in future MATLAB releases.
    tmpFile = [tempname, '.mat'];
    cleanup = onCleanup(@() delete(tmpFile));
    save(tmpFile, 'data', '-v7');
    fid = fopen(tmpFile, 'r');
    dataBytes = fread(fid, '*uint8');
    fclose(fid);

    md = java.security.MessageDigest.getInstance('MD5');
    md.update(dataBytes);
    hashBytes = md.digest();
    hash = sprintf('%02x', typecast(hashBytes, 'uint8'));
end
