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

    % Serialize data to a byte stream in memory to avoid disk I/O.
    % Note: getByteStreamFromArray is an undocumented internal MATLAB function.
    dataBytes = getByteStreamFromArray(data);
    
    md = java.security.MessageDigest.getInstance('MD5');
    md.update(dataBytes);
    hashBytes = md.digest();
    hash = sprintf('%02x', typecast(hashBytes, 'uint8'));
end
