function im0 = erodeC ( im0 )

% Adds a zero padding to each dimension of the image.
im0 = padarray ( im0, [ 1 1 1 ] );

% Creates shifted versions of the image.
im1 = circshift ( im0, [  1  0  0 ] );
im2 = circshift ( im0, [ -1  0  0 ] );

% Applies the binary erosion.
im0 = im0 & im1 & im2;

% Creates shifted versions of the image.
im1 = circshift ( im0, [  0 -1  0 ] );
im2 = circshift ( im0, [  0  1  0 ] );

% Applies the binary erosion.
im0 = im0 & im1 & im2;

% Creates shifted versions of the image.
im1 = circshift ( im0, [  0  0  1 ] );
im2 = circshift ( im0, [  0  0 -1 ] );

% Applies the binary erosion.
im0 = im0 & im1 & im2;

% Removes the padding.
im0 = im0 ( 2: end - 1, 2: end - 1, 2: end - 1 );
