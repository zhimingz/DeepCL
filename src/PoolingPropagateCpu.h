// Copyright Hugh Perkins 2014 hughperkins at gmail
//
// This Source Code Form is subject to the terms of the Mozilla Public License, 
// v. 2.0. If a copy of the MPL was not distributed with this file, You can 
// obtain one at http://mozilla.org/MPL/2.0/.

#pragma once

#include "PoolingPropagate.h"

#define VIRTUAL virtual
#define STATIC static

class PoolingPropagateCpu : public PoolingPropagate {
public:

    // [[[cog
    // import cog_addheaders
    // cog_addheaders.add()
    // ]]]
    // generated, using cog:
    PoolingPropagateCpu( OpenCLHelper *cl, bool padZeros, int numPlanes, int inputImageSize, int poolingSize );
    VIRTUAL void propagate( int batchSize, CLWrapper *inputWrapper, CLWrapper *selectorsWrapper, CLWrapper *outputWrapper );
    VIRTUAL void propagate( int batchSize, float *input, int *selectors, float *output );

    // [[[end]]]
};

