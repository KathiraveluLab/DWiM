function flatS = flattenStruct(S, prefix)
    % FLATTENSTRUCT Recursively flattens a nested DICOM struct.
    % Logic: Converts nested sequences into a single-level struct.
    
    if nargin < 2
        prefix = '';
    end

    flatS = struct();
    fields = fieldnames(S);

    for i = 1:numel(fields)
        fieldName = fields{i};
        value = S.(fieldName);
        
        % Generate the key name based on current prefix
        if isempty(prefix)
            newKey = fieldName;
        else
            newKey = sprintf('%s_%s', prefix, fieldName);
        end

        if isstruct(value)
            % Explicitly use full package path for recursive call
            subFlat = dwim.internal.flattenStruct(value, newKey);
            flatS = mergeStructs(flatS, subFlat);
            
        elseif iscell(value)
            % Handle DICOM Sequences (cell arrays of structs)
            for j = 1:numel(value)
                if isstruct(value{j})
                    itemKey = sprintf('%s_Item%d', newKey, j);
                    % Explicitly use full package path for recursive call
                    subFlat = dwim.internal.flattenStruct(value{j}, itemKey);
                    flatS = mergeStructs(flatS, subFlat);
                end
            end
        else
            % Base Case: Simple value
            flatS.(newKey) = value;
        end
    end
end

function A = mergeStructs(A, B)
    % Internal helper to merge fields (DRY compliance)
    f = fieldnames(B);
    for i = 1:numel(f)
        A.(f{i}) = B.(f{i});
    end
end