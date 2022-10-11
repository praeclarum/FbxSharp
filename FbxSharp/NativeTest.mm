#include "FbxSharp.h"
#import <ModelIO/ModelIO.h>

#include <objc/runtime.h>

static int numSuccess = 0;
static int numFails = 0;

int testFailed(const char *msg) {
    printf("FAIL: %s\n", msg);
    numFails++;
    return 1;
}

int testSuccess() {
    printf("SUCCESS\n");
    numSuccess++;
    return 0;
}

int testFromModelIO() {
    NSLog(@"TEST FROM MODELIO");
    auto asset = [[MDLAsset alloc] initWithURL:[NSURL fileURLWithPath:@"../TestFiles/obj/fox.obj"]];
    if (!asset) {
        return testFailed("Cannot create asset");
    }
    auto errors = [[NSMutableArray alloc] init];
    FbxScene *scene = fbxConvertModelIOToScene(asset, errors);
    if (!scene) {
        return testFailed("Cannot convert asset to scene");
    }
    fbxSaveScene(scene, "../TestOutputFiles/fox_ModelIOToFbx.fbx", -1, 0, 0);
    fbxSaveScene(scene, "../TestOutputFiles/fox_ModelIOToFbx_a.fbx", -1, 0, 1);
    fbxSaveScene(scene, "../TestOutputFiles/fox_ModelIOToFbx.dae", -1, 0, 0);
    fbxSaveScene(scene, "../TestOutputFiles/fox_ModelIOToFbx.obj", -1, 0, 0);
    return testSuccess();
}

int main(int argc, char *argv[])
{
    @autoreleasepool {
        testFromModelIO();
    }
    printf("%d tests succeeded, %d tests failed\n", numSuccess, numFails);
    return numFails > 0 ? 1 : 0;
}
