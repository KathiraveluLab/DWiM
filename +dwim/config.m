function conf = config()
%config Returns the central configuration settings for DWiM.
%
%   conf = dwim.config() returns a struct containing default settings
%   for Orthanc connections, file paths, and other project-wide constants.
%
%   Note: Uses Singleton Pattern (persistent variable) for performance.

    persistent cachedConf;

    if isempty(cachedConf)
        % --- Orthanc Settings (Environment Variables with Fallbacks) ---
        
        % Attempt to read from secure environment variables first
        envBaseURL = getenv('DWIM_ORTHANC_BASEURL');
        envUser    = getenv('DWIM_ORTHANC_USER');
        envPass    = getenv('DWIM_ORTHANC_PASSWORD');

        % Apply defaults only if environment variables are not set
        if isempty(envBaseURL)
            cachedConf.Orthanc.BaseURL = "http://localhost:8042"; 
        else
            cachedConf.Orthanc.BaseURL = string(envBaseURL); 
        end

        if isempty(envUser)
            % Default public credential for local Orthanc Docker instance
            cachedConf.Orthanc.User = "orthanc"; 
        else
            cachedConf.Orthanc.User = string(envUser); 
        end

        if isempty(envPass)
             % Default public credential for local Orthanc Docker instance
            cachedConf.Orthanc.Password = "orthanc"; 
        else
            cachedConf.Orthanc.Password = string(envPass); 
        end

        % --- Default Behaviors ---
        cachedConf.Defaults.Verbose = true;
    end

    % Return the cached configuration
    conf = cachedConf;
end