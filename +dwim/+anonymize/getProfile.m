function attributes = getProfile(profileName)
    % GETPROFILE Returns a struct of DICOM tags to update based on the mode.
    
    arguments
        profileName (1,1) string
    end

    switch lower(profileName)
        case 'strict'
            % HIPAA Safe: Remove/Mask absolutely everything identifying
            attributes = struct();
            attributes.PatientName = 'ANONYMIZED';
            attributes.PatientID = 'ANONYMIZED';
            attributes.PatientBirthDate = ''; % Empty string tells MATLAB to clear it
            attributes.PatientSex = '';
            attributes.PatientAge = '';
            attributes.StudyDate = '';
            attributes.InstitutionName = 'ANONYMIZED_LAB';

        case 'research'
            % Research Mode: Keep Age/Sex/Dates for analysis, hide Identity
            attributes = struct();
            attributes.PatientName = 'RESEARCH_SUB'; 
            attributes.PatientID = 'RES_001';
            % Note: We DO NOT list Age/Sex here. 
            % By omitting them, dicomanon preserves the original values.
            attributes.InstitutionName = 'RESEARCH_LAB';

        case 'minimal'
            % Minimal: Just remove the name, keep everything else
            attributes = struct();
            attributes.PatientName = 'ANONYMIZED';

        otherwise
            error('DWiM:UnknownProfile', 'Profile "%s" is not defined.', profileName);
    end
end