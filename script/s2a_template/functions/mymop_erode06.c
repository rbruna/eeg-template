/* Function to perform morphological erosion in a binary volume.
 * This function uses a 1-radius ball as structuring element
 * (6-connectivity).
 * 
 * See mym_erode26 for a similar function using a cube as structuring
 * element (26-connectivity).
 */

#include <string.h>
#include <math.h>
#include "mex.h"
#include "matrix.h"

void erodeR ( mxLogical *im1, const mxLogical *im0, const mwSize *size ) {
    
    int offs [3];
    int xindex, yindex, zindex;
    int vindex;
    
    
    /* Calculates the offsets */
    offs [0] = 1;
    offs [1] = size [0];
    offs [2] = size [0] * size [1];
    
    /* Goes through each dimension. */
    for ( zindex = 1; zindex < size [2] - 1; zindex ++ ) {
        for ( yindex = 1; yindex < size [1] - 1; yindex ++ ) {
            for ( xindex = 1; xindex < size [0] - 1; xindex ++ ) {
                
                /* Gets the current voxel of the image. */
                vindex = zindex * offs [2] + yindex * offs [1] + xindex * offs [0];
                
                /* Applies the binary dilation. */
                im1 [vindex] = im0 [vindex] &
                        im0 [vindex-offs[0]] &
                        im0 [vindex+offs[0]] &
                        im0 [vindex-offs[1]] &
                        im0 [vindex+offs[1]] &
                        im0 [vindex-offs[2]] &
                        im0 [vindex+offs[2]];
            }
        }
    }
}

void mexFunction ( int nlhs, mxArray * plhs [], int nrhs, const mxArray * prhs [] ) {
    
    mxLogical *im0, *im1;
    mwSize dims;
    const mwSize *size;
    
    /* Checks the inputs. */
    if ( nrhs < 1 || nrhs > 1 ) mexErrMsgTxt ( "Invalid number of arguments." );
    if ( !mxIsLogical ( prhs [0] ) ) mexErrMsgTxt ( "This function only accepts logicals as input." );
    
    /* Gets the data size. */
    dims = mxGetNumberOfDimensions ( prhs [0] );
    size = mxGetDimensions ( prhs [0] );
    if ( dims != 3 ) mexErrMsgTxt ( "This function requires a 3-D matrix as input." );
    
    
    /* Gets the input variable. */
    im0 = mxGetData ( prhs [0] );
    
    /* Creates the output variable. */
    plhs [0] = mxCreateLogicalArray ( dims, size );
    im1 = mxGetData ( plhs [0] );
    
    
    /* Erodes the original image into the output one. */
    erodeR ( im1, im0, size );
}
