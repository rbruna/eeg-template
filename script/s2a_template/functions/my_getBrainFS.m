function asegmask = my_getBrainFS ( mri )

% Gets the gray matter.
asegmask   = mri.aseg > 0;

% Fixes the mask.
asegmask   = dilateO2 ( asegmask );
asegmask   = imfill   ( asegmask, 'holes' );
asegmask   = erodeO2  ( asegmask );
