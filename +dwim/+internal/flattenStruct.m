function flatS = flattenStruct(S, prefix)
    % FLATTENSTRUCT Recursively flattens a nested DICOM struct.
    % Path: C:\Users\surya\DWiM\+dwim\+internal\flattenStruct.m
    
    if nargin < 2
        prefix = '';
    end

    flatS = struct();
    fields = fieldnames(S);

    for i = 1:numel(fields)
        fieldName = fields{i};
        value = S.(fieldName);
        
        % Construct the new key name with dot-notation style underscore
        if isempty(prefix)
            newKey = fieldName;
        else
            newKey = sprintf('%s_%s', prefix, fieldName);
        end

        if isstruct(value)
            % Recursive call for nested structs
            subFlat = dwim.internal.flattenStruct(value, newKey);
            flatS = mergeStructs(flatS, subFlat);
            
        elseif iscell(value)
            % Handle DICOM Sequences (cell arrays of structs)
            for j = 1:numel(value)
                if isstruct(value{j})
                    itemKey = sprintf('%s_Item%d', newKey, j);
                    subFlat = dwim.internal.flattenStruct(value{j}, itemKey);
                    flatS = mergeStructs(flatS, subFlat);
                end
            end
        else
            % Base Case: Simple value (numeric, string, etc.)
            flatS.(newKey) = value;
        end
    end
end

function A = mergeStructs(A, B)
    % Helper to merge fields of struct B into A (Internal DRY utility)
    f = fieldnames(B);
    for i = 1:numel(f)
        A.(f{i}) = B.(f{i});
    end
end