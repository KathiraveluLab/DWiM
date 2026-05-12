function conf = config()
%config Returns the central configuration settings for DWiM.
%
%   conf = dwim.config() returns a struct containing default settings
%   for Orthanc connections, file paths, and other project-wide constants.
%
%   Outputs:
%       conf - (struct) Configuration structure with fields:
%           .Orthanc.BaseURL  - Default Orthanc server URL
%           .Orthanc.User     - Default username
%           .Orthanc.Password - Default password
%           .Defaults.Verbose - Default verbosity setting
%
%   Example:
%       settings = dwim.config();
%       disp(settings.Orthanc.BaseURL);
%
%   Note: Uses Singleton Pattern (persistent variable) for performance.

    persistent cachedConf;

    if isempty(cachedConf)
        % --- Orthanc Settings ---
        % Use a helper to check environment variables 
        cachedConf.Orthanc.BaseURL  = getEnvOrDefault('DWIM_ORTHANC_BASEURL', "http://localhost:8042");
        cachedConf.Orthanc.User     = getEnvOrDefault('DWIM_ORTHANC_USER', "orthanc");
        cachedConf.Orthanc.Password = getEnvOrDefault('DWIM_ORTHANC_PASSWORD', "orthanc");

        % --- Default Behaviors ---
        cachedConf.Defaults.Verbose = true;
    end

    % Return the cached configuration
    conf = cachedConf;
end

function val = getEnvOrDefault(envKey, defaultVal)
%getEnvOrDefault Helper to read env var safely
    val = string(getenv(envKey));
    if val == ""
        val = string(defaultVal);
    end
end
