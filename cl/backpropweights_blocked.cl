// Copyright Hugh Perkins 2014,2015 hughperkins at gmail
//
// This Source Code Form is subject to the terms of the Mozilla Public License, 
// v. 2.0. If a copy of the MPL was not distributed with this file, You can 
// obtain one at http://mozilla.org/MPL/2.0/.

// expected defines:
// BIASED (or not)

// blockRow, blockCol
// blockPos
// margin
// localInRow, localInCol
// localOutRow, localOutCol
// 

//typedef struct tag_block {
//    int pos;
//} block;

#include "ids.cl"
#include "cl/copyLocal.cl"
#include "cl/copyBlock.cl"

//#define posToRow( pos ) ( ( pos >> 10 ) & (2^11-1) )
//#define posToCol( pos ) ( ( pos ) & (2^11-1) )
//#define rowColToPos( row, col ) ( ( row << 10 ) | col )
//#define linearIdToPos( linearId, base ) ( rowColToPos( ( linearId / base ), ( linearId % base )  ) )

// workgroupId: [outputPlane][inputPlane][blockRow][blockCol]
// localId: [filterRow][filterCol]
// per-thread iteration: [n][outputRow][outputCol]
// local: errorimage: blockSize * blockSize
//        imageimage: inputImageSize * inputImageSize
void kernel backprop_floats_withscratch_dobias( 
        const float learningRateMultiplier, const int batchSize, 
         global const float *errors, global const float *images, 
        global float *weights,
        #ifdef BIASED
             global float *biasWeights,
        #endif
        local float *_errorImage, local float *_imageImage
 ) {
    #define globalId ( get_global_id(0) )
    #define localId ( get_local_id(0)  )
    #define workgroupId ( get_group_id(0) )
    #define workgroupSize ( get_local_size(0) )

//    const int filterRow = localId / gFilterSize;
//    const int filterCol = localId % gFilterSize;
    const int filterPos = linearIdToPos( localId, gFilterSize )
    const int inOutPlane = linearIdToPos( workgroupId, gInputPlanes )

//    #define outPlane ( workgroupId / gInputPlanes )
//    #define upstreamPlane ( workgroupId % gInputPlanes )

    // weights:     [outPlane][upstreamPlane][filterRow][filterCol]
    //       aggregate over:  [outRow][outCol][n]
    float thiswchange = 0;
#ifdef BIASED
    float thisbiaschange = 0;
#endif
    for( int n = 0; n < batchSize; n++ ) {
        barrier(CLK_LOCAL_MEM_FENCE);
        copyLocal( _imageImage, images + ( n * gInputPlanes + upstreamPlane ) * gInputImageSizeSquared, 
            gInputImageSizeSquared );
        copyLocal( _errorImage, errors + ( n * gNumFilters + outPlane ) * gOutputImageSizeSquared,
            gOutputImageSizeSquared );
        barrier(CLK_LOCAL_MEM_FENCE);
        if( localId < gFilterSizeSquared ) {
            for( int outRow = 0; outRow < gOutputImageSize; outRow++ ) {
                int upstreamRow = outRow - gMargin + filterRow;
                for( int outCol = 0; outCol < gOutputImageSize; outCol++ ) {
                    const int upstreamCol = outCol - gMargin + filterCol;
                    #define proceed ( upstreamRow >= 0 && upstreamCol >= 0 && upstreamRow < gInputImageSize && upstreamCol < gInputImageSize )
                    if( proceed ) {
                        // these defines reduce register pressure, compared to const
                        // giving a 40% speedup on nvidia :-)
                        #define resultIndex ( outRow * gOutputImageSize + outCol )
                        #define error ( _errorImage[resultIndex] )
                        //const float error = _errorImage[resultIndex];
                        #define upstreamDataIndex ( upstreamRow * gInputImageSize + upstreamCol )
                        #define upstreamResult ( _imageImage[upstreamDataIndex] )
                        thiswchange += upstreamResult * error;
    #ifdef BIASED
                        thisbiaschange += error;
    #endif
                    }
                }
            }
        }
    }
    if( localId < gFilterSizeSquared ) {
        weights[ workgroupId * gFilterSizeSquared + localId ] = learningRateMultiplier * thiswchange;
    }
#ifdef BIASED
    #define writeBias ( upstreamPlane == 0 && localId == 0 )
    if( writeBias ) {
        biasWeights[outPlane] = learningRateMultiplier * thisbiaschange;
    }
#endif
    // weights:     [outPlane][upstreamPlane][filterRow][filterCol]
    //       aggregate over:  [outRow][outCol][n]
}

