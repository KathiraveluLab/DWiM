function [updateAttributes, keepAttributes] = getProfile(profileName)
    % GETPROFILE Returns update rules AND keep rules for anonymization.
    
    arguments
        profileName (1,1) string
    end

    % Default: Keep nothing
    keepAttributes = {}; 

    switch lower(profileName)
        case 'strict'
            updateAttributes = struct();
            updateAttributes.PatientName = 'ANONYMIZED';
            updateAttributes.PatientID = 'ANONYMIZED';
            updateAttributes.PatientBirthDate = '';
            updateAttributes.PatientSex = '';
            updateAttributes.PatientAge = '';
            updateAttributes.StudyDate = '';
            updateAttributes.InstitutionName = 'ANONYMIZED_LAB';

        case 'research'
            % Research: Mask Identity, but KEEP Demographics
            updateAttributes = struct();
            updateAttributes.PatientName = 'RESEARCH_SUB'; 
            updateAttributes.InstitutionName = 'RESEARCH_LAB';
            % Logic centralized in scrub.m
            
            % Explicitly tell dicomanon NOT to remove these
            keepAttributes = {'PatientAge', 'PatientSex'};

        case 'minimal'
            updateAttributes = struct();
            updateAttributes.PatientName = 'ANONYMIZED';

        otherwise
            error('DWiM:UnknownProfile', 'Profile "%s" is not defined.', profileName);
    end
end