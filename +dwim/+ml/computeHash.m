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

    % Use getByteStreamFromArray for robust, deterministic, in-memory
    % serialization of any MATLAB variable. This avoids the 2GB limit of
    % save(...,'-v7'), MAT-file header timestamp non-determinism, and the
    % HDF5 incompatibility with the 128-byte skip trick used by '-v7.3'.
    try
        bytes = getByteStreamFromArray(data);
    catch ME
        if strcmp(ME.identifier, 'MATLAB:undefinedVarOrFun')
            error('dwim:ml:computeHash:Unsupported', ...
                  'getByteStreamFromArray is not available. A different robust serialization method is required.');
        else
            rethrow(ME);
        end
    end

    % Hash the byte stream using MD5.
    md = java.security.MessageDigest.getInstance('MD5');
    md.update(bytes);
    hashBytes = md.digest();
    hash = sprintf('%02x', typecast(hashBytes, 'uint8'));
end
