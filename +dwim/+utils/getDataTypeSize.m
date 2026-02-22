function bytes = getDataTypeSize(dataType)
%GETDATATYPESIZE Get size in bytes for MATLAB data type
%
%   bytes = dwim.utils.getDataTypeSize(dataType)
%       Returns the number of bytes per element for a given MATLAB data type
%
%   Inputs:
%       dataType - String or char array specifying MATLAB data type
%
%   Outputs:
%       bytes - Number of bytes per element (1, 2, 4, or 8)
%
%   Example:
%       bytes = dwim.utils.getDataTypeSize('single');  % Returns 4

    switch dataType
        case {'int8', 'uint8'}
            bytes = 1;
        case {'int16', 'uint16'}
            bytes = 2;
        case {'int32', 'uint32', 'single'}
            bytes = 4;
        case {'int64', 'uint64', 'double'}
            bytes = 8;
        otherwise
            bytes = 8;  % Conservative fallback
    end
end
