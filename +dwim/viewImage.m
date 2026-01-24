function viewImage(img, titleStr)
    % VIEWIMAGE Displays a DICOM image with optimized contrast.
    
    arguments
        img (:,:) double
        titleStr (1,1) string = "DICOM Preview"
    end

    figure;
    imagesc(img); 
    colormap gray; 
    axis image; 
    colorbar;
    
    % FIX: Set 'Interpreter' to 'none' to handle file paths safely
    title(titleStr, 'Interpreter', 'none'); 
    
    xlabel('Pixels (Width)');
    ylabel('Pixels (Height)');
end