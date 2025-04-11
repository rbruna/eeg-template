function skullmask = my_getSkullpCT ( mri )

% Gets a skull estimation from the pseudo-CT.

% Gets a estimation of the scalp and the brain.
scalpmask  = mri.m_scalp;
brainmask  = mri.white + mri.gray + mri.csf > .5;


% Defines the thresholds for the fisrt and second passes.
threshold1 = 500;
threshold2 = 250;

% Gets the skull.
skullmask  = mri.pct > threshold1;

% Removes the points outside the scalp.
skullmask  = skullmask .* single ( scalpmask );

% Forces the minimum skull thickness.
skullmask  = skullmask | dilateC ( dilateC ( brainmask ) );

% Fixes the skull.
skullmask  = dilateC  ( skullmask );
skullmask  = imfill   ( skullmask, 'holes' );
skullmask  = erodeC   ( skullmask );


% Gets the biggest connected element.
skullmask  = erodeC   ( skullmask );
skullmask  = bwlabeln ( skullmask, 6 );
skullmask  = skullmask == mode ( skullmask ( skullmask ~= 0 ) );
skullmask  = dilateC  ( skullmask );

% Dilates the image.
skullmask  = dilateO2 ( skullmask );

% Goes back to the original image.
skullmask  = skullmask & mri.pct > threshold2;

% Forces the minimum skull thickness.
skullmask  = skullmask | dilateC ( dilateC ( brainmask ) );

% Keeps only the biggest connected element.
skullmask  = bwlabeln ( skullmask, 6 );
skullmask  = ( skullmask == mode ( skullmask ( skullmask ~= 0 ) ) );

% Fixes the skull.
skullmask  = dilateC  ( skullmask );
skullmask  = imfill   ( skullmask, 'holes' );
skullmask  = erodeC   ( skullmask );
