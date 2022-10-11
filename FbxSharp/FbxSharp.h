#pragma once

#include <fbxsdk.h>
#include <ModelIO/ModelIO.h>

extern FbxManager *TheSdkManager;

void InitializeSdkObjects(FbxManager*& pManager, FbxScene*& pScene, const char *name);

extern "C" {

FbxScene *fbxConvertModelIOToScene(MDLAsset *asset, NSMutableArray *errors);
MDLAsset *fbxConvertSceneToModelIO(FbxScene *scene, MDLAsset *asset, NSMutableArray *errors);
int fbxSaveScene(FbxScene *scene, const char *path, int fileFormat, int embedMedia, int forceAscii);

}

