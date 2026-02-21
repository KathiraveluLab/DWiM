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
    if fid == -1
        error('dwim:ml:computeHash:FileError', ...
              'Failed to open temporary file for hashing.');
    end

    % Skip the 128-byte MAT-file header which contains a 'Created on'
    % timestamp. Without this, the hash is non-deterministic across runs.
    fseek(fid, 128, 'bof');

    % Hash in 1 MB chunks to avoid OOM errors on large datasets.
    md = java.security.MessageDigest.getInstance('MD5');
    chunkSize = 1024 * 1024;  % 1 MB
    while ~feof(fid)
        chunk = fread(fid, chunkSize, '*uint8');
        if ~isempty(chunk)
            md.update(chunk);
        end
    end
    fclose(fid);

    hashBytes = md.digest();
    hash = sprintf('%02x', typecast(hashBytes, 'uint8'));
end
