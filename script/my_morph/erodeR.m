function im3 = erodeR ( im0 )

% Adds a zero padding to each dimension of the image.
im0 = padarray ( im0, [ 1 1 1 ] );
im3 = im0;

% Creates shifted versions of the image.
im1 = circshift ( im0, [  1  0  0 ] );
im2 = circshift ( im0, [ -1  0  0 ] );

% Applies the binary erosion.
im3 = im3 & im1 & im2;

% Creates shifted versions of the image.
im1 = circshift ( im0, [  0 -1  0 ] );
im2 = circshift ( im0, [  0  1  0 ] );

% Applies the binary erosion.
im3 = im3 & im1 & im2;

% Creates shifted versions of the image.
im1 = circshift ( im0, [  0  0  1 ] );
im2 = circshift ( im0, [  0  0 -1 ] );

% Applies the binary erosion.
im3 = im3 & im1 & im2;

% Removes the padding.
im3 = im3 ( 2: end - 1, 2: end - 1, 2: end - 1 );
